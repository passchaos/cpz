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

pub const Finish = struct {
    question_id: QuestionId,
    release_result_caps: bool,

    pub fn releasesResultCaps(self: @This()) bool {
        return self.release_result_caps;
    }
};

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

pub const ExceptionType = enum(u16) {
    failed = 0,
    overloaded = 1,
    disconnected = 2,
    unimplemented = 3,
};

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

    pub fn total(self: @This()) usize {
        return self.response_initialized + self.forward_required + self.state_applied;
    }

    pub fn hasWork(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.total() == 0;
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

    pub fn unifiedDenseOutputPosition(self: @This(), output_index: usize) ?WireDispatchOutputPosition {
        return wireDispatchUnifiedDenseOutputPosition(self, output_index);
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

    pub fn validateDenseOutputBuilders(self: @This(), response_messages: anytype, forward_messages: anytype) Error!void {
        try self.validateDenseOutputCapacity(response_messages.len, forward_messages.len);
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

    pub fn questionId(self: @This()) QuestionId {
        return switch (self) {
            .provide, .accept, .join => |value| value.question_id,
        };
    }

    pub fn exportId(self: @This()) ExportId {
        return switch (self) {
            .provide, .accept, .join => |value| value.export_id,
        };
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
        switch (completion) {
            .provide => self.provides += 1,
            .accept => self.accepts += 1,
            .join => self.joins += 1,
        }
    }

    pub fn recordPosition(self: *@This(), position: HandoffReturnOutputPosition) void {
        switch (position.role) {
            .provide => self.provides += 1,
            .accept => self.accepts += 1,
            .join => self.joins += 1,
        }
    }

    pub fn recordOutputIndex(self: *@This(), source_stats: StateHandoffReturnStats, output_index: usize) Error!void {
        const position = source_stats.unifiedOutputPosition(output_index) orelse return error.InvalidTransition;
        self.recordPosition(position);
    }

    pub fn nextPosition(self: @This(), completion: HandoffReturn) HandoffReturnOutputPosition {
        return switch (completion.outputRole()) {
            .provide => .{ .role = .provide, .local_index = self.provides },
            .accept => .{ .role = .accept, .local_index = self.accepts },
            .join => .{ .role = .join, .local_index = self.joins },
        };
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

    pub fn validateOutputCapacity(self: @This(), response_capacity: usize, forward_capacity: usize) Error!void {
        if (response_capacity < self.responseMessages()) return error.InvalidTransition;
        if (forward_capacity < self.forwardedMessages()) return error.InvalidTransition;
    }

    pub fn validateUnifiedOutputCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.totalOutputMessages()) return error.InvalidTransition;
    }

    pub fn validateUnifiedOutputBuilders(self: @This(), output_messages: anytype) Error!void {
        try self.validateUnifiedOutputCapacity(output_messages.len);
    }

    pub fn validateOutputBuilders(self: @This(), response_messages: anytype, forward_messages: anytype) Error!void {
        try self.validateOutputCapacity(response_messages.len, forward_messages.len);
    }

    pub fn validateDisembargoCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.disembargoMessages()) return error.InvalidTransition;
    }

    pub fn validateOutputBuilderSets(self: @This(), response_messages: anytype, forward_messages: anytype, disembargo_messages: anytype) Error!void {
        try self.validateOutputBuilders(response_messages, forward_messages);
        try self.validateDisembargoCapacity(disembargo_messages.len);
    }
};

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

    pub fn matchesDispatchStats(self: @This(), dispatch: WireDispatchStats) bool {
        const expected = @This().fromDispatchStats(dispatch);
        return self.responses == expected.responses and
            self.forwards == expected.forwards and
            self.disembargos == expected.disembargos;
    }

    pub fn matchesTurnPlan(self: @This(), turn_plan: RpcTurnPlan) bool {
        const expected = @This().fromTurnPlan(turn_plan);
        return self.responses == expected.responses and
            self.forwards == expected.forwards and
            self.disembargos == expected.disembargos;
    }

    pub fn matchesServiceActionStats(self: @This(), stats: TrackedCallServiceActionStats) bool {
        const expected = @This().fromServiceActionStats(stats);
        return self.responses == expected.responses and
            self.forwards == expected.forwards and
            self.disembargos == expected.disembargos;
    }

    pub fn validateAgainstDispatchStats(self: @This(), dispatch: WireDispatchStats) Error!void {
        if (!self.matchesDispatchStats(dispatch)) return error.InvalidTransition;
    }

    pub fn validateAgainstTurnPlan(self: @This(), turn_plan: RpcTurnPlan) Error!void {
        if (!self.matchesTurnPlan(turn_plan)) return error.InvalidTransition;
    }

    pub fn validateAgainstServiceActionStats(self: @This(), stats: TrackedCallServiceActionStats) Error!void {
        if (!self.matchesServiceActionStats(stats)) return error.InvalidTransition;
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

fn anyPointerUsageFromWire(pointer: anytype) !AnyPointerUsage {
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

fn capDescriptorsFromInfosAlloc(allocator: std.mem.Allocator, infos: []const CapDescriptorInfo) std.mem.Allocator.Error![]CapDescriptor {
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

pub fn dispatchWireCallServiceActionPlans(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !usize {
    var response_count: usize = 0;
    for (plans) |plan| {
        switch (plan.action) {
            .dispatch => |entry_index| {
                if (plan.source_index >= calls.len) return error.InvalidTransition;
                if (plan.question_id != calls[plan.source_index].questionId()) return error.InvalidTransition;
                if (response_count >= response_messages.len) return error.InvalidTransition;
                var matched = false;
                inline for (entries, 0..) |entry, index| {
                    if (index == entry_index) {
                        try dispatchCallMethod(state, allocator, response_messages[response_count], calls[plan.source_index], entry.method, context, entry.handler);
                        response_count += 1;
                        matched = true;
                    }
                }
                if (!matched) return error.InvalidTransition;
            },
            .forward, .unimplemented => {},
        }
    }
    return response_count;
}

fn validateWireCallServiceActionPlans(calls: anytype, plans: []const TrackedCallServiceActionPlan, comptime entries: anytype) Error!TrackedCallServiceActionStats {
    var stats: TrackedCallServiceActionStats = .{};
    for (plans) |plan| {
        if (plan.source_index >= calls.len) return error.InvalidTransition;
        if (plan.question_id != calls[plan.source_index].questionId()) return error.InvalidTransition;
        switch (plan.action) {
            .dispatch => |entry_index| {
                var matched = false;
                inline for (entries, 0..) |_, index| {
                    if (index == entry_index) matched = true;
                }
                if (!matched) return error.InvalidTransition;
            },
            .forward, .unimplemented => {},
        }
        stats.record(plan.action);
    }
    return stats;
}

fn validateWireMessageServiceActionPlans(messages: anytype, plans: []const TrackedCallServiceActionPlan, comptime entries: anytype) !TrackedCallServiceActionStats {
    var stats: TrackedCallServiceActionStats = .{};
    for (plans) |plan| {
        if (plan.source_index >= messages.len) return error.InvalidTransition;
        const call = try messages[plan.source_index].call();
        if (plan.question_id != call.questionId()) return error.InvalidTransition;
        switch (plan.action) {
            .dispatch => |entry_index| {
                var matched = false;
                inline for (entries, 0..) |_, index| {
                    if (index == entry_index) matched = true;
                }
                if (!matched) return error.InvalidTransition;
            },
            .forward, .unimplemented => {},
        }
        stats.record(plan.action);
    }
    return stats;
}

pub fn initWireCallServiceActionPlanOutputs(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    forward_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !TrackedCallServiceActionStats {
    const stats = try validateWireCallServiceActionPlans(calls, plans, entries);
    try stats.validateOutputBuilders(response_messages, forward_messages);

    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (plans) |plan| {
        switch (plan.action) {
            .dispatch => |entry_index| {
                inline for (entries, 0..) |entry, index| {
                    if (index == entry_index) {
                        try dispatchCallMethod(state, allocator, response_messages[response_index], calls[plan.source_index], entry.method, context, entry.handler);
                        response_index += 1;
                    }
                }
            },
            .forward => |target| {
                try initForwardedWireCallMessage(forward_messages[forward_index], calls[plan.source_index], target);
                forward_index += 1;
            },
            .unimplemented => {
                try initWireReturnException(try response_messages[response_index].init_return_(), calls[plan.source_index].questionId(), true, false, .{
                    .reason = "unimplemented method",
                    .type_raw = 3,
                });
                response_index += 1;
            },
        }
    }
    return stats;
}

pub fn initWireCallServiceActionPlanOutputsToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    forward_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanOutputs(state, allocator, calls, plans, response_messages, forward_messages, context, entries);
    for (try stats.outputResponseRange().slice(response_messages)) |message| try response_handler(response_context, message);
    for (forward_messages[0..stats.forward]) |message| try forward_handler(forward_context, message);
    return stats;
}

pub fn initWireMessageServiceActionPlanOutputs(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    forward_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !TrackedCallServiceActionStats {
    const stats = try validateWireMessageServiceActionPlans(messages, plans, entries);
    try stats.validateOutputBuilders(response_messages, forward_messages);

    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (plans) |plan| {
        const call = try messages[plan.source_index].call();
        switch (plan.action) {
            .dispatch => |entry_index| {
                inline for (entries, 0..) |entry, index| {
                    if (index == entry_index) {
                        try dispatchCallMethod(state, allocator, response_messages[response_index], call, entry.method, context, entry.handler);
                        response_index += 1;
                    }
                }
            },
            .forward => |target| {
                try initForwardedWireCallMessage(forward_messages[forward_index], call, target);
                forward_index += 1;
            },
            .unimplemented => {
                try initWireReturnException(try response_messages[response_index].init_return_(), call.questionId(), true, false, .{
                    .reason = "unimplemented method",
                    .type_raw = 3,
                });
                response_index += 1;
            },
        }
    }
    return stats;
}

pub fn initWireMessageServiceActionPlanOutputsToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    forward_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanOutputs(state, allocator, messages, plans, response_messages, forward_messages, context, entries);
    for (try stats.outputResponseRange().slice(response_messages)) |message| try response_handler(response_context, message);
    for (forward_messages[0..stats.forward]) |message| try forward_handler(forward_context, message);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputs(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !TrackedCallServiceActionStats {
    const stats = try validateWireCallServiceActionPlans(calls, plans, entries);
    try stats.validateActionCapacity(output_messages.len);
    return initWireCallServiceActionPlanOutputs(
        state,
        allocator,
        calls,
        plans,
        try stats.outputResponseRange().slice(output_messages),
        try stats.outputForwardRange().slice(output_messages),
        context,
        entries,
    );
}

pub fn sendRpcServiceActionUnifiedOutputsToSink(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    _ = try sendRpcServiceActionUnifiedOutputsToSinkStats(stats, output_messages, sink_context, sink_handler);
}

pub fn sendRpcServiceActionUnifiedOutputsToSinkStats(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (output_messages[0..stats.actions()]) |message| try sink_handler(sink_context, message);
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputsToQueue(allocator: std.mem.Allocator, stats: TrackedCallServiceActionStats, output_messages: anytype, queue: anytype) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (output_messages[0..stats.actions()]) |message| try queue.append(allocator, message);
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputsToQueues(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (try stats.outputResponseRange().slice(output_messages)) |message| {
        try response_queue.append(allocator, message);
    }
    for (try stats.outputForwardRange().slice(output_messages)) |message| {
        try forward_queue.append(allocator, message);
    }
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputsToTaggedQueue(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    queue: anytype,
) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    var output_stats: RpcOutputStats = .{};
    for (output_messages[0..stats.actions()], 0..) |message, output_index| {
        const position = trackedCallServiceActionUnifiedOutputPosition(stats, output_index).?;
        try queue.append(allocator, .{ .position = position, .message = message });
        output_stats.recordServiceActionPosition(position);
    }
    return output_stats;
}

/// Append source-preserving service-action outputs to an embedder-owned queue.
///
/// The compact unified output buffer is ordered as responses first, then
/// forwarded Calls.  The original service-action plans can be in source order,
/// so this helper walks the plans by action kind and pairs each output builder
/// with the plan that produced it.  Queue element types should provide
/// `plan` and `message` fields, for example:
/// `struct { plan: TrackedCallServiceActionPlan, message: Message.Builder }`.
pub fn appendRpcServiceActionUnifiedOutputPlansToQueue(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    queue: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);

    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try queue.append(allocator, .{ .plan = plan, .message = output_messages[response_index] });
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try queue.append(allocator, .{ .plan = plan, .message = output_messages[response_index] });
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try queue.append(allocator, .{ .plan = plan, .message = output_messages[forward_index] });
            forward_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputPlansToQueues(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);

    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try response_queue.append(allocator, .{ .plan = plan, .message = output_messages[response_index] });
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try response_queue.append(allocator, .{ .plan = plan, .message = output_messages[response_index] });
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try forward_queue.append(allocator, .{ .plan = plan, .message = output_messages[forward_index] });
            forward_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    queue: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);

    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    var response_local_index: usize = 0;
    var forward_local_index: usize = 0;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            const position: TrackedCallServiceActionOutputPosition = .{ .role = .response, .local_index = response_local_index };
            try queue.append(allocator, .{ .plan = plan, .position = position, .message = output_messages[response_index] });
            response_index += 1;
            response_local_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            const position: TrackedCallServiceActionOutputPosition = .{ .role = .response, .local_index = response_local_index };
            try queue.append(allocator, .{ .plan = plan, .position = position, .message = output_messages[response_index] });
            response_index += 1;
            response_local_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            const position: TrackedCallServiceActionOutputPosition = .{ .role = .forward, .local_index = forward_local_index };
            try queue.append(allocator, .{ .plan = plan, .position = position, .message = output_messages[forward_index] });
            forward_index += 1;
            forward_local_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputsToTaggedSink(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    _ = try sendRpcServiceActionUnifiedOutputsToTaggedSinkStats(stats, output_messages, sink_context, sink_handler);
}

pub fn sendRpcServiceActionUnifiedOutputsToTaggedSinkStats(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (output_messages[0..stats.actions()], 0..) |message, output_index| {
        try sink_handler(sink_context, trackedCallServiceActionUnifiedOutputPosition(stats, output_index).?, message);
    }
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputsToSinks(
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !void {
    _ = try sendRpcServiceActionUnifiedOutputsToSinksStats(stats, output_messages, response_context, response_handler, forward_context, forward_handler);
}

pub fn sendRpcServiceActionUnifiedOutputsToSinksStats(
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (try stats.outputResponseRange().slice(output_messages)) |message| try response_handler(response_context, message);
    for (try stats.outputForwardRange().slice(output_messages)) |message| try forward_handler(forward_context, message);
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSink(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !void {
    _ = try sendRpcServiceActionUnifiedOutputPlansToSinkStats(stats, plans, output_messages, sink_context, sink_handler);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSinkStats(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);
    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try sink_handler(sink_context, plan, output_messages[response_index]);
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try sink_handler(sink_context, plan, output_messages[response_index]);
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try sink_handler(sink_context, plan, output_messages[forward_index]);
            forward_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSinks(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !void {
    _ = try sendRpcServiceActionUnifiedOutputPlansToSinksStats(stats, plans, output_messages, response_context, response_handler, forward_context, forward_handler);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSinksStats(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);
    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try response_handler(response_context, plan, output_messages[response_index]);
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try response_handler(response_context, plan, output_messages[response_index]);
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try forward_handler(forward_context, plan, output_messages[forward_index]);
            forward_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToTaggedSink(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !void {
    _ = try sendRpcServiceActionUnifiedOutputPlansToTaggedSinkStats(stats, plans, output_messages, sink_context, sink_handler);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToTaggedSinkStats(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);
    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    var response_local_index: usize = 0;
    var forward_local_index: usize = 0;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try sink_handler(sink_context, plan, .{ .role = .response, .local_index = response_local_index }, output_messages[response_index]);
            response_index += 1;
            response_local_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try sink_handler(sink_context, plan, .{ .role = .response, .local_index = response_local_index }, output_messages[response_index]);
            response_index += 1;
            response_local_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try sink_handler(sink_context, plan, .{ .role = .forward, .local_index = forward_local_index }, output_messages[forward_index]);
            forward_index += 1;
            forward_local_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToSink(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToSink(stats, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToQueue(allocator, stats, output_messages, queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToQueues(allocator, stats, output_messages, response_queue, forward_queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToSinks(stats, output_messages, response_context, response_handler, forward_context, forward_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToTaggedSink(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToTaggedSink(stats, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToTaggedQueue(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToTaggedQueue(allocator, stats, output_messages, queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToSink(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToSink(stats, plans, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToQueue(allocator, stats, plans, output_messages, queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToQueues(allocator, stats, plans, output_messages, response_queue, forward_queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToSinks(stats, plans, output_messages, response_context, response_handler, forward_context, forward_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToTaggedSink(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToTaggedSink(stats, plans, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToTaggedQueue(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(allocator, stats, plans, output_messages, queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputs(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !TrackedCallServiceActionStats {
    const stats = try validateWireMessageServiceActionPlans(messages, plans, entries);
    try stats.validateActionCapacity(output_messages.len);
    return initWireMessageServiceActionPlanOutputs(
        state,
        allocator,
        messages,
        plans,
        try stats.outputResponseRange().slice(output_messages),
        try stats.outputForwardRange().slice(output_messages),
        context,
        entries,
    );
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToSink(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToSink(stats, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToQueue(allocator, stats, output_messages, queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToQueues(allocator, stats, output_messages, response_queue, forward_queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToSinks(stats, output_messages, response_context, response_handler, forward_context, forward_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToTaggedSink(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToTaggedSink(stats, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToTaggedQueue(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToTaggedQueue(allocator, stats, output_messages, queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToSink(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToSink(stats, plans, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToQueue(allocator, stats, plans, output_messages, queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToQueues(allocator, stats, plans, output_messages, response_queue, forward_queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToSinks(stats, plans, output_messages, response_context, response_handler, forward_context, forward_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToTaggedSink(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToTaggedSink(stats, plans, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToTaggedQueue(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(allocator, stats, plans, output_messages, queue);
    return stats;
}

pub fn initForwardedWireCallToResolvedTarget(state: *const State, call: anytype, source_call: anytype) !CallTarget {
    const target = (try state.wireCallTargetTransitiveForwardTarget(source_call)) orelse return error.InvalidTransition;
    try initForwardedWireCall(call, source_call, target);
    return target;
}

pub fn initForwardedWireCallMessageToResolvedTarget(state: *const State, message: anytype, source_call: anytype) !CallTarget {
    const target = (try state.wireCallTargetTransitiveForwardTarget(source_call)) orelse return error.InvalidTransition;
    try initForwardedWireCallMessage(message, source_call, target);
    return target;
}

pub fn initWireCallWithOptions(
    allocator: std.mem.Allocator,
    call: anytype,
    question_id: QuestionId,
    target: CallTarget,
    registry: anytype,
    options: CallOptions,
) !void {
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallParamsCapTable(call, descriptors);
}

fn initWireCallHeaderWithOptions(
    call: anytype,
    question_id: QuestionId,
    target: CallTarget,
    options: CallOptions,
) !void {
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try writeCallOptionsToWire(options, call);
}

pub fn initWireCall(allocator: std.mem.Allocator, call: anytype, question_id: QuestionId, target: CallTarget, registry: anytype) !void {
    try initWireCallWithOptions(allocator, call, question_id, target, registry, .{});
}

pub fn initWireCallMessageWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    registry: anytype,
    options: CallOptions,
) !void {
    try initWireCallWithOptions(allocator, try message.init_call(), question_id, target, registry, options);
}

pub fn initWireCallMessage(allocator: std.mem.Allocator, message: anytype, question_id: QuestionId, target: CallTarget, registry: anytype) !void {
    try initWireCall(allocator, try message.init_call(), question_id, target, registry);
}

pub fn initWireCallMessagePayloadCapability(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsCapability(call, capability_index, descriptors);
}

pub fn initWireCallMessagePayloadCapabilityWithOptions(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsCapability(call, capability_index, descriptors);
}

pub fn initWireCallMessagePayloadCapabilityWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    if (capability_index >= descriptors.len) return error.InvalidCapabilityPointer;
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    try initWireCallMessagePayloadCapabilityWithOptions(message, question_id, target, capability_index, descriptors, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessagePayloadCapabilityAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    try initWireCallMessagePayloadCapabilityWithOptionsAndApplyState(state, message, question_id, target, capability_index, descriptors, .{});
}

pub fn initWireCallMessagePayloadCapabilityInfo(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsCapabilityInfo(call, capability_index, infos);
}

pub fn initWireCallMessagePayloadCapabilityInfoWithOptions(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsCapabilityInfo(call, capability_index, infos);
}

pub fn initWireCallMessagePayloadCapabilityInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    if (capability_index >= infos.len) return error.InvalidCapabilityPointer;
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    try initWireCallMessagePayloadCapabilityInfoWithOptions(message, question_id, target, capability_index, infos, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessagePayloadCapabilityInfoAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
) !void {
    try initWireCallMessagePayloadCapabilityInfoWithOptionsAndApplyState(state, message, question_id, target, capability_index, infos, .{});
}

pub fn initWireCallMessagePayloadCapabilityFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    registry: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsCapabilityFromRegistry(allocator, call, capability_index, registry);
}

pub fn initWireCallMessagePayloadCapabilityFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    registry: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsCapabilityFromRegistry(allocator, call, capability_index, registry);
}

pub fn initWireCallMessagePayloadCapabilityFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    registry: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessagePayloadCapabilityWithOptionsAndApplyState(
        state,
        message,
        question_id,
        target,
        capability_index,
        descriptors,
        options,
    );
}

pub fn initWireCallMessagePayloadCapabilityFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    registry: anytype,
) !void {
    try initWireCallMessagePayloadCapabilityFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, capability_index, registry, .{});
}

pub fn initWireCallMessageStructWith(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsStructWith(call, struct_size, descriptors, context, fill);
}

pub fn initWireCallMessageStructWithOptions(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsStructWith(call, struct_size, descriptors, context, fill);
}

pub fn initWireCallMessageStructWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);

    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    const params = try call.init_params();
    const content_pointer = try params.get_contentAsPointer();
    const content = try content_pointer.initStruct(struct_size);
    try fill(context, content);
    if ((try content.validate()).maxCapabilityCount() > descriptors.len) return error.InvalidCapabilityPointer;
    try initWirePayloadCapTable(params, descriptors);

    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageStructWithAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    try initWireCallMessageStructWithOptionsAndApplyState(state, message, question_id, target, struct_size, descriptors, context, fill, .{});
}

pub fn initWireCallMessageStructInfoWith(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsStructInfoWith(call, struct_size, infos, context, fill);
}

pub fn initWireCallMessageStructInfoWithOptions(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsStructInfoWith(call, struct_size, infos, context, fill);
}

pub fn initWireCallMessageStructInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);

    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    const params = try call.init_params();
    const content_pointer = try params.get_contentAsPointer();
    const content = try content_pointer.initStruct(struct_size);
    try fill(context, content);
    if ((try content.validate()).maxCapabilityCount() > infos.len) return error.InvalidCapabilityPointer;
    try initWirePayloadCapTableInfo(params, infos);

    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageStructInfoWithAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    try initWireCallMessageStructInfoWithOptionsAndApplyState(state, message, question_id, target, struct_size, infos, context, fill, .{});
}

pub fn initWireCallMessageStructFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsStructFromRegistry(allocator, call, struct_size, registry, context, fill);
}

pub fn initWireCallMessageStructFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsStructFromRegistry(allocator, call, struct_size, registry, context, fill);
}

pub fn initWireCallMessageStructFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessageStructWithOptionsAndApplyState(
        state,
        message,
        question_id,
        target,
        struct_size,
        descriptors,
        context,
        fill,
        options,
    );
}

pub fn initWireCallMessageStructFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    try initWireCallMessageStructFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, struct_size, registry, context, fill, .{});
}

pub fn initWireCallMessageText(message: anytype, question_id: QuestionId, target: CallTarget, text: []const u8, descriptors: []const CapDescriptor) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsText(call, text, descriptors);
}

pub fn initWireCallMessageTextWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, text: []const u8, descriptors: []const CapDescriptor, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsText(call, text, descriptors);
}

pub fn initWireCallMessageTextWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    try initWireCallMessageTextWithOptions(message, question_id, target, text, descriptors, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageTextAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    try initWireCallMessageTextWithOptionsAndApplyState(state, message, question_id, target, text, descriptors, .{});
}

pub fn initWireCallMessageData(message: anytype, question_id: QuestionId, target: CallTarget, data: []const u8, descriptors: []const CapDescriptor) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsData(call, data, descriptors);
}

pub fn initWireCallMessageDataWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, data: []const u8, descriptors: []const CapDescriptor, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsData(call, data, descriptors);
}

pub fn initWireCallMessageDataWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    try initWireCallMessageDataWithOptions(message, question_id, target, data, descriptors, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageDataAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    try initWireCallMessageDataWithOptionsAndApplyState(state, message, question_id, target, data, descriptors, .{});
}

pub fn initWireCallMessageUInt32List(message: anytype, question_id: QuestionId, target: CallTarget, values: []const u32, descriptors: []const CapDescriptor) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsUInt32List(call, values, descriptors);
}

pub fn initWireCallMessageUInt32ListWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, values: []const u32, descriptors: []const CapDescriptor, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsUInt32List(call, values, descriptors);
}

pub fn initWireCallMessageUInt32ListWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    try initWireCallMessageUInt32ListWithOptions(message, question_id, target, values, descriptors, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageUInt32ListAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    descriptors: []const CapDescriptor,
) !void {
    try initWireCallMessageUInt32ListWithOptionsAndApplyState(state, message, question_id, target, values, descriptors, .{});
}

pub fn initWireCallMessageTextInfo(message: anytype, question_id: QuestionId, target: CallTarget, text: []const u8, infos: []const CapDescriptorInfo) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsTextInfo(call, text, infos);
}

pub fn initWireCallMessageTextInfoWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, text: []const u8, infos: []const CapDescriptorInfo, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsTextInfo(call, text, infos);
}

pub fn initWireCallMessageTextInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    try initWireCallMessageTextInfoWithOptions(message, question_id, target, text, infos, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageTextInfoAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    try initWireCallMessageTextInfoWithOptionsAndApplyState(state, message, question_id, target, text, infos, .{});
}

pub fn initWireCallMessageDataInfo(message: anytype, question_id: QuestionId, target: CallTarget, data: []const u8, infos: []const CapDescriptorInfo) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsDataInfo(call, data, infos);
}

pub fn initWireCallMessageDataInfoWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, data: []const u8, infos: []const CapDescriptorInfo, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsDataInfo(call, data, infos);
}

pub fn initWireCallMessageDataInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    try initWireCallMessageDataInfoWithOptions(message, question_id, target, data, infos, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageDataInfoAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    try initWireCallMessageDataInfoWithOptionsAndApplyState(state, message, question_id, target, data, infos, .{});
}

pub fn initWireCallMessageUInt32ListInfo(message: anytype, question_id: QuestionId, target: CallTarget, values: []const u32, infos: []const CapDescriptorInfo) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsUInt32ListInfo(call, values, infos);
}

pub fn initWireCallMessageUInt32ListInfoWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, values: []const u32, infos: []const CapDescriptorInfo, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsUInt32ListInfo(call, values, infos);
}

pub fn initWireCallMessageUInt32ListInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    try initWireCallMessageUInt32ListInfoWithOptions(message, question_id, target, values, infos, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageUInt32ListInfoAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    infos: []const CapDescriptorInfo,
) !void {
    try initWireCallMessageUInt32ListInfoWithOptionsAndApplyState(state, message, question_id, target, values, infos, .{});
}

pub fn initWireCallMessageTextFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    registry: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsTextFromRegistry(allocator, call, text, registry);
}

pub fn initWireCallMessageTextFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    registry: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsTextFromRegistry(allocator, call, text, registry);
}

pub fn initWireCallMessageTextFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    registry: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessageTextWithOptionsAndApplyState(state, message, question_id, target, text, descriptors, options);
}

pub fn initWireCallMessageTextFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    registry: anytype,
) !void {
    try initWireCallMessageTextFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, text, registry, .{});
}

pub fn initWireCallMessageDataFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    registry: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsDataFromRegistry(allocator, call, data, registry);
}

pub fn initWireCallMessageDataFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    registry: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsDataFromRegistry(allocator, call, data, registry);
}

pub fn initWireCallMessageDataFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    registry: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessageDataWithOptionsAndApplyState(state, message, question_id, target, data, descriptors, options);
}

pub fn initWireCallMessageDataFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    registry: anytype,
) !void {
    try initWireCallMessageDataFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, data, registry, .{});
}

pub fn initWireCallMessageUInt32ListFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    registry: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsUInt32ListFromRegistry(allocator, call, values, registry);
}

pub fn initWireCallMessageUInt32ListFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    registry: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsUInt32ListFromRegistry(allocator, call, values, registry);
}

pub fn initWireCallMessageUInt32ListFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    registry: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessageUInt32ListWithOptionsAndApplyState(state, message, question_id, target, values, descriptors, options);
}

pub fn initWireCallMessageUInt32ListFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    registry: anytype,
) !void {
    try initWireCallMessageUInt32ListFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, values, registry, .{});
}

pub fn initWireBootstrap(bootstrap: anytype, question_id: QuestionId) !void {
    try bootstrap.set_questionId(question_id);
}

pub fn initWireBootstrapMessage(message: anytype, question_id: QuestionId) !void {
    try initWireBootstrap(try message.init_bootstrap(), question_id);
}

pub fn initWireReturn(
    allocator: std.mem.Allocator,
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    registry: anytype,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnResultsCapTable(return_, descriptors);
}

pub fn initWireReturnAwaitFromThirdParty(
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try return_.set_awaitFromThirdParty_capability(capability_index);
}

fn applyInitializedNonResultReturnState(
    state: *State,
    answer_id: AnswerId,
    release_param_caps: bool,
) !void {
    if (release_param_caps) try state.validateParamImports(answer_id);
    try state.resolveAnswer(answer_id, .return_);
    try state.trackResultImports(answer_id, &.{});
    if (release_param_caps) try state.releaseParamImports(answer_id);
}

pub fn initWireReturnAwaitFromThirdPartyMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
) !void {
    try initWireReturnAwaitFromThirdParty(try message.init_return_(), answer_id, release_param_caps, no_finish_needed, capability_index);
    try applyInitializedNonResultReturnState(state, answer_id, release_param_caps);
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

pub fn initWireReturnExceptionMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    exception: ExceptionInfo,
) !void {
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnException(try message.init_return_(), answer_id, release_param_caps, no_finish_needed, exception);
    try state.resolveAnswer(answer_id, .return_);
    try state.trackResultImports(answer_id, &.{});
    if (release_param_caps) try state.releaseParamImports(answer_id);
}

pub fn initWireReturnCanceled(return_: anytype, answer_id: AnswerId, release_param_caps: bool) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_canceled();
}

pub fn initWireReturnCanceledMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
) !void {
    try initWireReturnCanceled(try message.init_return_(), answer_id, release_param_caps);
    try applyInitializedNonResultReturnState(state, answer_id, release_param_caps);
}

pub fn initWireReturnResultsSentElsewhere(return_: anytype, answer_id: AnswerId, release_param_caps: bool) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_resultsSentElsewhere();
}

pub fn initWireReturnResultsSentElsewhereMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
) !void {
    try initWireReturnResultsSentElsewhere(try message.init_return_(), answer_id, release_param_caps);
    try applyInitializedNonResultReturnState(state, answer_id, release_param_caps);
}

pub fn initWireReturnTakeFromOtherQuestion(
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    other_question_id: QuestionId,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_takeFromOtherQuestion(other_question_id);
}

pub fn initWireReturnTakeFromOtherQuestionMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    other_question_id: QuestionId,
) !void {
    if (!state.answers.contains(other_question_id)) return error.QuestionNotOpen;
    try initWireReturnTakeFromOtherQuestion(try message.init_return_(), answer_id, release_param_caps, other_question_id);
    try applyInitializedNonResultReturnState(state, answer_id, release_param_caps);
}

pub fn initWireReturnMessage(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    registry: anytype,
) !void {
    try initWireReturn(allocator, try message.init_return_(), answer_id, release_param_caps, no_finish_needed, registry);
}

pub fn initWireReturnMessagePayloadCapability(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsCapability(return_, capability_index, descriptors);
}

pub fn initWireReturnMessagePayloadCapabilityAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    if (capability_index >= descriptors.len) return error.InvalidCapabilityPointer;
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessagePayloadCapability(message, answer_id, release_param_caps, no_finish_needed, capability_index, descriptors);
    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessagePayloadCapabilityInfo(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsCapabilityInfo(return_, capability_index, infos);
}

pub fn initWireReturnMessagePayloadCapabilityInfoAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
) !void {
    if (capability_index >= infos.len) return error.InvalidCapabilityPointer;
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessagePayloadCapabilityInfo(message, answer_id, release_param_caps, no_finish_needed, capability_index, infos);
    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessagePayloadCapabilityFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    registry: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsCapabilityFromRegistry(allocator, return_, capability_index, registry);
}

pub fn initWireReturnMessagePayloadCapabilityFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    registry: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessagePayloadCapabilityAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        capability_index,
        descriptors,
    );
}

pub fn initWireReturnMessageStructWith(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsStructWith(return_, struct_size, descriptors, context, fill);
}

pub fn initWireReturnMessageStructWithAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);

    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    const results = try return_.init_results();
    const content_pointer = try results.get_contentAsPointer();
    const content = try content_pointer.initStruct(struct_size);
    try fill(context, content);
    if ((try content.validate()).maxCapabilityCount() > descriptors.len) return error.InvalidCapabilityPointer;
    try initWirePayloadCapTable(results, descriptors);

    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageStructInfoWith(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsStructInfoWith(return_, struct_size, infos, context, fill);
}

pub fn initWireReturnMessageStructInfoWithAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);

    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    const results = try return_.init_results();
    const content_pointer = try results.get_contentAsPointer();
    const content = try content_pointer.initStruct(struct_size);
    try fill(context, content);
    if ((try content.validate()).maxCapabilityCount() > infos.len) return error.InvalidCapabilityPointer;
    try initWirePayloadCapTableInfo(results, infos);

    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageStructFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsStructFromRegistry(allocator, return_, struct_size, registry, context, fill);
}

pub fn initWireReturnMessageStructFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessageStructWithAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        struct_size,
        descriptors,
        context,
        fill,
    );
}

pub fn initWireReturnMessageText(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsText(return_, text, descriptors);
}

pub fn initWireReturnMessageTextAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageText(message, answer_id, release_param_caps, no_finish_needed, text, descriptors);
    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageData(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsData(return_, data, descriptors);
}

pub fn initWireReturnMessageDataAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageData(message, answer_id, release_param_caps, no_finish_needed, data, descriptors);
    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageUInt32List(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    descriptors: []const CapDescriptor,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsUInt32List(return_, values, descriptors);
}

pub fn initWireReturnMessageUInt32ListAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    descriptors: []const CapDescriptor,
) !void {
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageUInt32List(message, answer_id, release_param_caps, no_finish_needed, values, descriptors);
    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageTextInfo(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsTextInfo(return_, text, infos);
}

pub fn initWireReturnMessageTextInfoAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageTextInfo(message, answer_id, release_param_caps, no_finish_needed, text, infos);
    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageDataInfo(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsDataInfo(return_, data, infos);
}

pub fn initWireReturnMessageDataInfoAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageDataInfo(message, answer_id, release_param_caps, no_finish_needed, data, infos);
    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageUInt32ListInfo(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    infos: []const CapDescriptorInfo,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsUInt32ListInfo(return_, values, infos);
}

pub fn initWireReturnMessageUInt32ListInfoAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    infos: []const CapDescriptorInfo,
) !void {
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageUInt32ListInfo(message, answer_id, release_param_caps, no_finish_needed, values, infos);
    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageTextFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    registry: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsTextFromRegistry(allocator, return_, text, registry);
}

pub fn initWireReturnMessageTextFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    registry: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessageTextAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        text,
        descriptors,
    );
}

pub fn initWireReturnMessageDataFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    registry: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsDataFromRegistry(allocator, return_, data, registry);
}

pub fn initWireReturnMessageDataFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    registry: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessageDataAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        data,
        descriptors,
    );
}

pub fn initWireReturnMessageUInt32ListFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    registry: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsUInt32ListFromRegistry(allocator, return_, values, registry);
}

pub fn initWireReturnMessageUInt32ListFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    registry: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessageUInt32ListAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        values,
        descriptors,
    );
}

pub fn joinResultCapabilityFromWireReturn(return_: anytype) !?u32 {
    const outcome = try returnOutcomeFromWireReturn(return_);
    if (outcome != .results) return null;
    return payloadContentCapabilityIndex(try return_.results());
}

pub fn initWireJoinResultReturn(
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try initWireReturnResultsCapability(return_, capability_index, descriptors);
}

pub fn initWireJoinResultReturnMessage(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    try initWireJoinResultReturn(try message.init_return_(), answer_id, release_param_caps, capability_index, descriptors);
}

pub fn initCapabilityReturnMessage(message: anytype, answer_id: AnswerId, export_id: ExportId) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try initWirePayloadCapability(try return_.init_results(), 0, &.{.{ .sender_hosted = export_id }});
}

pub fn initEmptyReturnMessage(message: anytype, answer_id: AnswerId, release_param_caps: bool, no_finish_needed: bool) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    _ = try return_.init_results();
}

pub fn initEmptyReturnMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
) !void {
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initEmptyReturnMessage(message, answer_id, release_param_caps, no_finish_needed);
    try state.resolveAnswer(answer_id, .return_);
    try state.trackResultImports(answer_id, &.{});
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initDispatchReturnMessage(message: anytype, answer_id: AnswerId, result: DispatchResult) !void {
    return switch (result) {
        .empty => initEmptyReturnMessage(message, answer_id, true, true),
        .capability => |export_id| initCapabilityReturnMessage(message, answer_id, export_id),
        .text => |text| initWireReturnMessageText(message, answer_id, true, false, text, &.{}),
        .data => |data| initWireReturnMessageData(message, answer_id, true, false, data, &.{}),
        .uint32_list => |values| initWireReturnMessageUInt32List(message, answer_id, true, false, values, &.{}),
        .exception => |exception| initWireReturnException(try message.init_return_(), answer_id, true, false, exception),
        .canceled => initWireReturnCanceled(try message.init_return_(), answer_id, true),
        .results_sent_elsewhere => initWireReturnResultsSentElsewhere(try message.init_return_(), answer_id, true),
        .take_from_other_question => |question_id| initWireReturnTakeFromOtherQuestion(try message.init_return_(), answer_id, true, question_id),
        .await_from_third_party => |capability_index| initWireReturnAwaitFromThirdParty(try message.init_return_(), answer_id, true, false, capability_index),
    };
}

pub fn initDispatchReturnMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    result: DispatchResult,
) !void {
    return switch (result) {
        .empty => initEmptyReturnMessageAndApplyState(state, message, answer_id, true, true),
        .capability => |export_id| initWireReturnMessagePayloadCapabilityAndApplyState(
            state,
            message,
            answer_id,
            true,
            false,
            0,
            &.{.{ .sender_hosted = export_id }},
        ),
        .text => |text| initWireReturnMessageTextAndApplyState(state, message, answer_id, true, false, text, &.{}),
        .data => |data| initWireReturnMessageDataAndApplyState(state, message, answer_id, true, false, data, &.{}),
        .uint32_list => |values| initWireReturnMessageUInt32ListAndApplyState(state, message, answer_id, true, false, values, &.{}),
        .exception => |exception| initWireReturnExceptionMessageAndApplyState(state, message, answer_id, true, false, exception),
        .canceled => initWireReturnCanceledMessageAndApplyState(state, message, answer_id, true),
        .results_sent_elsewhere => initWireReturnResultsSentElsewhereMessageAndApplyState(state, message, answer_id, true),
        .take_from_other_question => |question_id| initWireReturnTakeFromOtherQuestionMessageAndApplyState(state, message, answer_id, true, question_id),
        .await_from_third_party => |capability_index| initWireReturnAwaitFromThirdPartyMessageAndApplyState(state, message, answer_id, true, false, capability_index),
    };
}

pub fn initBootstrapReturnMessage(message: anytype, answer_id: AnswerId, export_id: ExportId) !void {
    try initCapabilityReturnMessage(message, answer_id, export_id);
}

pub fn initBootstrapReturnForRequest(message: anytype, bootstrap: anytype, export_id: ExportId) !void {
    try initBootstrapReturnMessage(message, bootstrap.questionId(), export_id);
}

pub fn dispatchBootstrap(
    state: *State,
    response_message: anytype,
    bootstrap: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireEvent(.{ .bootstrap = bootstrap.questionId() });
    const export_id = try handler(context, bootstrap);
    try initBootstrapReturnForRequest(response_message, bootstrap, export_id);
}

pub fn dispatchCallReturningCapability(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const export_id = try handler(context, call);
    try initCapabilityReturnMessage(response_message, call.questionId(), export_id);
}

pub fn dispatchCallReturningCapabilityForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallReturningCapability(state, allocator, response_message, call, context, handler);
    return .response_initialized;
}

pub fn dispatchCallReturningEmpty(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    try handler(context, call);
    try initEmptyReturnMessage(response_message, call.questionId(), true, true);
}

pub fn dispatchCallReturningEmptyForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallReturningEmpty(state, allocator, response_message, call, context, handler);
    return .response_initialized;
}

pub fn dispatchCallReturningText(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageText(response_message, call.questionId(), true, false, text, &.{});
}

pub fn dispatchCallReturningData(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageData(response_message, call.questionId(), true, false, data, &.{});
}

pub fn dispatchCallReturningUInt32List(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32List(response_message, call.questionId(), true, false, values, &.{});
}

pub fn dispatchCallReturningTextInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageTextInfo(response_message, call.questionId(), true, false, text, infos);
}

pub fn dispatchCallReturningDataInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageDataInfo(response_message, call.questionId(), true, false, data, infos);
}

pub fn dispatchCallReturningUInt32ListInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32ListInfo(response_message, call.questionId(), true, false, values, infos);
}

pub fn dispatchCallReturningTextFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageTextFromRegistry(allocator, response_message, call.questionId(), true, false, text, registry);
}

pub fn dispatchCallReturningTextForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageText(response_message, call.questionId(), true, false, text, descriptors);
    return .response_initialized;
}

pub fn dispatchCallReturningTextInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageTextInfo(response_message, call.questionId(), true, false, text, infos);
    return .response_initialized;
}

pub fn dispatchCallReturningTextFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallReturningTextForwardingOutcome(state, allocator, response_message, forward_message, call, descriptors, context, handler);
}

pub fn dispatchCallReturningDataFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageDataFromRegistry(allocator, response_message, call.questionId(), true, false, data, registry);
}

pub fn dispatchCallReturningDataForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageData(response_message, call.questionId(), true, false, data, descriptors);
    return .response_initialized;
}

pub fn dispatchCallReturningDataInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageDataInfo(response_message, call.questionId(), true, false, data, infos);
    return .response_initialized;
}

pub fn dispatchCallReturningDataFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallReturningDataForwardingOutcome(state, allocator, response_message, forward_message, call, descriptors, context, handler);
}

pub fn dispatchCallReturningUInt32ListFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32ListFromRegistry(allocator, response_message, call.questionId(), true, false, values, registry);
}

pub fn dispatchCallReturningUInt32ListForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32List(response_message, call.questionId(), true, false, values, descriptors);
    return .response_initialized;
}

pub fn dispatchCallReturningUInt32ListInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32ListInfo(response_message, call.questionId(), true, false, values, infos);
    return .response_initialized;
}

pub fn dispatchCallReturningUInt32ListFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallReturningUInt32ListForwardingOutcome(state, allocator, response_message, forward_message, call, descriptors, context, handler);
}

pub fn dispatchCallReturningStructWith(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const return_ = try response_message.init_return_();
    try return_.set_answerId(call.questionId());
    try return_.set_releaseParamCaps(true);
    try return_.set_noFinishNeeded(false);
    const results = try return_.init_results();
    const content = try (try results.get_contentAsPointer()).initStruct(struct_size);
    try handler(context, call, content);
    try initWirePayloadCapTable(results, descriptors);
}

pub fn dispatchCallReturningStructInfoWith(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const return_ = try response_message.init_return_();
    try return_.set_answerId(call.questionId());
    try return_.set_releaseParamCaps(true);
    try return_.set_noFinishNeeded(false);
    const results = try return_.init_results();
    const content = try (try results.get_contentAsPointer()).initStruct(struct_size);
    try handler(context, call, content);
    try initWirePayloadCapTableInfo(results, infos);
}

pub fn dispatchCallReturningStructFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallReturningStructWith(state, allocator, response_message, call, struct_size, descriptors, context, handler);
}

pub fn dispatchCallReturningStructForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallReturningStructWith(state, allocator, response_message, call, struct_size, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallReturningStructInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallReturningStructInfoWith(state, allocator, response_message, call, struct_size, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallReturningStructFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallReturningStructForwardingOutcome(state, allocator, response_message, forward_message, call, struct_size, descriptors, context, handler);
}

pub fn dispatchCall(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const result = try handler(context, call);
    try initDispatchReturnMessage(response_message, call.questionId(), result);
}

pub fn dispatchCallOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    // Keep this check before invoking the application handler. A resolved
    // imported promise is not a local service target anymore; treating it as
    // local would duplicate work that should be forwarded to the replacement
    // capability once a transport loop exists.
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCall(state, allocator, response_message, call, context, handler);
    return .response_initialized;
}

pub fn dispatchCallForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCall(state, allocator, response_message, call, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethod(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const result = try handler(context, call);
    try initDispatchReturnMessage(response_message, call.questionId(), result);
}

pub fn dispatchCallMethodReturningCapability(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const export_id = try handler(context, call);
    try initCapabilityReturnMessage(response_message, call.questionId(), export_id);
}

pub fn dispatchCallMethodReturningEmpty(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    try handler(context, call);
    try initEmptyReturnMessage(response_message, call.questionId(), true, true);
}

pub fn dispatchCallMethodReturningText(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const text = try handler(context, call);
    try initWireReturnMessageText(response_message, call.questionId(), true, false, text, descriptors);
}

pub fn dispatchCallMethodReturningTextInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const text = try handler(context, call);
    try initWireReturnMessageTextInfo(response_message, call.questionId(), true, false, text, infos);
}

pub fn dispatchCallMethodReturningTextFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallMethodReturningText(state, allocator, response_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningTextOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningText(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningTextForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningText(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningTextInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningTextInfo(state, allocator, response_message, call, expected_method, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningTextFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallMethodReturningTextForwardingOutcome(state, allocator, response_message, forward_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningData(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const data = try handler(context, call);
    try initWireReturnMessageData(response_message, call.questionId(), true, false, data, descriptors);
}

pub fn dispatchCallMethodReturningDataInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const data = try handler(context, call);
    try initWireReturnMessageDataInfo(response_message, call.questionId(), true, false, data, infos);
}

pub fn dispatchCallMethodReturningDataFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallMethodReturningData(state, allocator, response_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningDataOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningData(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningDataForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningData(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningDataInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningDataInfo(state, allocator, response_message, call, expected_method, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningDataFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallMethodReturningDataForwardingOutcome(state, allocator, response_message, forward_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningUInt32List(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const values = try handler(context, call);
    try initWireReturnMessageUInt32List(response_message, call.questionId(), true, false, values, descriptors);
}

pub fn dispatchCallMethodReturningUInt32ListInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const values = try handler(context, call);
    try initWireReturnMessageUInt32ListInfo(response_message, call.questionId(), true, false, values, infos);
}

pub fn dispatchCallMethodReturningUInt32ListFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallMethodReturningUInt32List(state, allocator, response_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningUInt32ListOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningUInt32List(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningUInt32ListForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningUInt32List(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningUInt32ListInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningUInt32ListInfo(state, allocator, response_message, call, expected_method, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningUInt32ListFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallMethodReturningUInt32ListForwardingOutcome(state, allocator, response_message, forward_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningStructWith(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const return_ = try response_message.init_return_();
    try return_.set_answerId(call.questionId());
    try return_.set_releaseParamCaps(true);
    try return_.set_noFinishNeeded(false);
    const results = try return_.init_results();
    const content = try (try results.get_contentAsPointer()).initStruct(struct_size);
    try handler(context, call, content);
    try initWirePayloadCapTable(results, descriptors);
}

pub fn dispatchCallMethodReturningStructInfoWith(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const return_ = try response_message.init_return_();
    try return_.set_answerId(call.questionId());
    try return_.set_releaseParamCaps(true);
    try return_.set_noFinishNeeded(false);
    const results = try return_.init_results();
    const content = try (try results.get_contentAsPointer()).initStruct(struct_size);
    try handler(context, call, content);
    try initWirePayloadCapTableInfo(results, infos);
}

pub fn dispatchCallMethodReturningStructFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallMethodReturningStructWith(state, allocator, response_message, call, expected_method, struct_size, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningStructOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningStructWith(state, allocator, response_message, call, expected_method, struct_size, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningStructForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningStructWith(state, allocator, response_message, call, expected_method, struct_size, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningStructInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningStructInfoWith(state, allocator, response_message, call, expected_method, struct_size, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningStructFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallMethodReturningStructForwardingOutcome(state, allocator, response_message, forward_message, call, expected_method, struct_size, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningCapabilityOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningCapability(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningCapabilityForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningCapability(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningEmptyOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningEmpty(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningEmptyForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningEmpty(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const dispatch_info = try state.wireCallDispatchInfo(call);
    if (dispatch_info.needsForward()) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethod(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const dispatch_info = try state.wireCallDispatchInfo(call);
    if (dispatch_info.needsForward()) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethod(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
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

pub fn wireCallMethodEntryIndex(call: anytype, comptime entries: anytype) Error!?usize {
    return callMethodEntryIndex(callMethodFromWireCall(call), entries);
}

pub fn wireMessageMethodEntryIndex(message: anytype, comptime entries: anytype) !?usize {
    const method = (try callMethodFromWireMessage(message)) orelse return null;
    return try callMethodEntryIndex(method, entries);
}

pub fn dispatchCallMethods(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    comptime entries: anytype,
) !void {
    try validateCallMethodEntries(entries);
    inline for (entries) |entry| {
        if (entry.method.matchesWireCall(call)) {
            try dispatchCallMethod(state, allocator, response_message, call, entry.method, context, entry.handler);
            return;
        }
    }

    try state.applyWireCall(allocator, call);
    try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
        .reason = "unimplemented method",
        .type_raw = 3,
    });
}

pub fn dispatchCallMethodsOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    comptime entries: anytype,
) !WireDispatchOutcome {
    try validateCallMethodEntries(entries);
    const dispatch_info = try state.wireCallDispatchInfo(call);
    if (dispatch_info.needsForward()) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethods(state, allocator, response_message, call, context, entries);
    return .response_initialized;
}

pub fn dispatchCallMethodsForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    context: anytype,
    comptime entries: anytype,
) !WireDispatchOutcome {
    try validateCallMethodEntries(entries);
    const dispatch_info = try state.wireCallDispatchInfo(call);
    if (dispatch_info.needsForward()) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethods(state, allocator, response_message, call, context, entries);
    return .response_initialized;
}

pub fn planWireMessageDispatch(state: *const State, request_message: anytype) !WireDispatchOutcome {
    switch (try wireMessageTag(request_message)) {
        .bootstrap => return .response_initialized,
        .call => {
            return try state.wireCallDispatchOutcome(try request_message.call());
        },
        else => return .state_applied,
    }
}

pub fn planWireMessagesDispatch(state: *const State, request_messages: anytype) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    for (request_messages) |request_message| {
        stats.record(try planWireMessageDispatch(state, request_message));
    }
    return stats;
}

pub fn planWireMessageMethodsDispatch(state: *const State, request_message: anytype, comptime call_entries: anytype) !WireDispatchOutcome {
    try validateCallMethodEntries(call_entries);
    return planWireMessageDispatch(state, request_message);
}

pub fn planWireMessagesMethodsDispatch(state: *const State, request_messages: anytype, comptime call_entries: anytype) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    for (request_messages) |request_message| {
        stats.record(try planWireMessageDispatch(state, request_message));
    }
    return stats;
}

pub fn planRpcTurn(state: *const State, request_messages: anytype) !RpcTurnPlan {
    return .{
        .dispatch = try planWireMessagesDispatch(state, request_messages),
        .handoff_returns = state.readyHandoffReturnStats(),
        .pending_disembargos = state.pendingAcceptEmbargoCount(),
    };
}

pub fn planRpcTurnMethods(state: *const State, request_messages: anytype, comptime call_entries: anytype) !RpcTurnPlan {
    return .{
        .dispatch = try planWireMessagesMethodsDispatch(state, request_messages, call_entries),
        .handoff_returns = state.readyHandoffReturnStats(),
        .pending_disembargos = state.pendingAcceptEmbargoCount(),
    };
}

pub fn planRpcTurnForAcceptEmbargo(state: *const State, request_messages: anytype, embargo: []const u8) !RpcTurnPlan {
    return .{
        .dispatch = try planWireMessagesDispatch(state, request_messages),
        .handoff_returns = state.readyHandoffReturnStats(),
        .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo),
    };
}

pub fn planRpcTurnMethodsForAcceptEmbargo(state: *const State, request_messages: anytype, comptime call_entries: anytype, embargo: []const u8) !RpcTurnPlan {
    return .{
        .dispatch = try planWireMessagesMethodsDispatch(state, request_messages, call_entries),
        .handoff_returns = state.readyHandoffReturnStats(),
        .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo),
    };
}

pub fn dispatchWireMessageOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallOutcome(state, allocator, response_message, try request_message.call(), call_context, call_handler);
        },
        else => {
            try state.applyWireMessage(allocator, request_message);
            return .state_applied;
        },
    }
}

fn applyStateWireMessageWithHandler(
    state: *State,
    allocator: std.mem.Allocator,
    request_message: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !void {
    var result = try state.applyWireMessageAlloc(allocator, request_message);
    defer result.deinit(allocator);
    try apply_handler(apply_context, result);
}

/// Variant of `dispatchWireMessageOutcome` for runtimes that need to observe
/// state-only apply details (for example released Accept IDs from Disembargo).
/// The callback receives a borrowed `WireMessageApplyResult`; copy any owned
/// slices before returning because dispatch deinitializes the result afterwards.
pub fn dispatchWireMessageOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallOutcome(state, allocator, response_message, try request_message.call(), call_context, call_handler);
        },
        else => {
            try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessage(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !bool {
    return (try dispatchWireMessageOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    )) == .response_initialized;
}

fn sendResponseMessageIfNeeded(outcome: WireDispatchOutcome, response_context: anytype, response_handler: anytype, response_message: anytype) !void {
    if (outcome == .response_initialized) {
        try response_handler(response_context, response_message);
    }
}

pub fn dispatchWireMessageToSinkOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    return outcome;
}

pub fn dispatchWireMessageToQueueOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    if (outcome == .response_initialized) {
        try queue.append(allocator, response_message);
    }
    return outcome;
}

pub fn dispatchWireMessageForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallForwardingOutcome(state, allocator, response_message, forward_message, try request_message.call(), call_context, call_handler);
        },
        else => {
            try state.applyWireMessage(allocator, request_message);
            return .state_applied;
        },
    }
}

fn sendForwardedMessageIfNeeded(outcome: WireDispatchOutcome, forward_context: anytype, forward_handler: anytype, forward_message: anytype) !void {
    if (outcome == .forward_required) {
        try forward_handler(forward_context, forward_message);
    }
}

fn ignoreInitializedMessage(_: void, _: anytype) !void {}

pub fn dispatchWireMessageForwardingToSinkOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageForwardingToQueueOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    if (outcome == .forward_required) {
        try queue.append(allocator, forward_message);
    }
    return outcome;
}

pub fn dispatchWireMessageForwardingToSinksOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageForwardingOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallForwardingOutcome(state, allocator, response_message, forward_message, try request_message.call(), call_context, call_handler);
        },
        else => {
            try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageForwardingToSinkOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageForwardingToQueueOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    if (outcome == .forward_required) {
        try queue.append(allocator, forward_message);
    }
    return outcome;
}

pub fn dispatchWireMessageForwardingToSinksOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallMethodsOutcome(state, allocator, response_message, try request_message.call(), call_context, call_entries);
        },
        else => {
            try state.applyWireMessage(allocator, request_message);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageMethodsToSinkOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsToQueueOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    if (outcome == .response_initialized) {
        try queue.append(allocator, response_message);
    }
    return outcome;
}

pub fn dispatchWireMessageMethodsOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallMethodsOutcome(state, allocator, response_message, try request_message.call(), call_context, call_entries);
        },
        else => {
            try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageMethodsToSinkOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsToQueueOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    if (outcome == .response_initialized) {
        try queue.append(allocator, response_message);
    }
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallMethodsForwardingOutcome(state, allocator, response_message, forward_message, try request_message.call(), call_context, call_entries);
        },
        else => {
            try state.applyWireMessage(allocator, request_message);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageMethodsForwardingToSinkOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingToQueueOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    if (outcome == .forward_required) {
        try queue.append(allocator, forward_message);
    }
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingToSinksOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallMethodsForwardingOutcome(state, allocator, response_message, forward_message, try request_message.call(), call_context, call_entries);
        },
        else => {
            try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageMethodsForwardingToSinkOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingToQueueOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    if (outcome == .forward_required) {
        try queue.append(allocator, forward_message);
    }
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingToSinksOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessages(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesWithOutcomeHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageToSinkOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            response_context,
            response_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        if (outcome == .response_initialized) {
            try queue.append(allocator, response_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessageToSinkOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    return outcome;
}

pub fn dispatchWireMessageToQueueOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    if (outcome == .response_initialized) {
        try queue.append(allocator, response_message);
    }
    return outcome;
}

pub fn dispatchWireMessagesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesWithOutcomeHandlerAndApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageToSinkOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            response_context,
            response_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        if (outcome == .response_initialized) {
            try queue.append(allocator, response_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToDenseSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    try state.applyWireCall(allocator, call);
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesToDenseSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    try state.applyWireCall(allocator, call);
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesDense(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesToDenseSink(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        {},
        ignoreInitializedMessage,
    );
}

pub fn dispatchWireMessagesDenseToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesDense(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesToDenseSinkWithApplyHandler(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        {},
        ignoreInitializedMessage,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesDenseToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwarding(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingWithOutcomeHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingToSinkOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            forward_context,
            forward_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        if (outcome == .forward_required) {
            try queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        if (outcome == .response_initialized) {
            try response_queue.append(allocator, response_messages[index]);
        } else if (outcome == .forward_required) {
            try forward_queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingToSinksOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingToSinkOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            forward_context,
            forward_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        if (outcome == .forward_required) {
            try queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingWithOutcomeHandlerAndApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        if (outcome == .response_initialized) {
            try response_queue.append(allocator, response_messages[index]);
        } else if (outcome == .forward_required) {
            try forward_queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToSinksWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingToSinksOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToDenseSinks(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    try forward_handler(forward_context, forward_messages[forward_index]);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToDenseSinksWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    try forward_handler(forward_context, forward_messages[forward_index]);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingDense(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingDenseToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingUnifiedDense(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesDispatch(state, request_messages);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    return dispatchWireMessagesForwardingDense(
        state,
        allocator,
        try planned.denseResponseRange().slice(output_messages),
        try planned.denseForwardRange().slice(output_messages),
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
}

pub fn dispatchWireMessagesForwardingUnifiedDenseToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesForwardingUnifiedDense(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    for (output_messages[0..stats.denseOutputSlots()]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingUnifiedDenseToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesDispatch(state, request_messages);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    const response_messages = try planned.denseResponseRange().slice(output_messages);
    const forward_messages = try planned.denseForwardRange().slice(output_messages);
    const stats = try dispatchWireMessagesForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingUnifiedDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesDispatch(state, request_messages);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    return dispatchWireMessagesForwardingDenseWithApplyHandler(
        state,
        allocator,
        try planned.denseResponseRange().slice(output_messages),
        try planned.denseForwardRange().slice(output_messages),
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesForwardingUnifiedDenseToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesForwardingUnifiedDenseWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    for (output_messages[0..stats.denseOutputSlots()]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingUnifiedDenseToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesDispatch(state, request_messages);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    const response_messages = try planned.denseResponseRange().slice(output_messages);
    const forward_messages = try planned.denseForwardRange().slice(output_messages);
    const stats = try dispatchWireMessagesForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesForwardingToDenseSinksWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        {},
        ignoreInitializedMessage,
        {},
        ignoreInitializedMessage,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesForwardingDenseToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

fn appliedRpcTurnPlan(state: *const State, dispatch: WireDispatchStats, handoff_returns: StateHandoffReturnStats) RpcTurnPlan {
    return .{
        .dispatch = dispatch,
        .handoff_returns = handoff_returns,
        // Dispatch can apply Accept or Disembargo messages before ready handoff
        // returns are materialized.  Report the pending queue after those state
        // transitions so the caller can immediately size or drain the follow-up
        // Disembargo output without recomputing a separate turn plan.
        .pending_disembargos = state.pendingAcceptEmbargoCount(),
    };
}

fn dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
    comptime method_dispatch: bool,
    comptime observe_apply: bool,
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_dispatch: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const ForwardedCall = struct {
        request_index: usize,
        target: CallTarget,
    };

    if (method_dispatch) try validateCallMethodEntries(call_dispatch);

    var dispatch_stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forwarded_calls = std.ArrayList(ForwardedCall).empty;
    defer forwarded_calls.deinit(allocator);

    for (request_messages, 0..) |request_message, request_index| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= output_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, output_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                response_index += 1;
                dispatch_stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if (try state.wireCallTargetTransitiveForwardTarget(call)) |target| {
                    try state.applyWireCall(allocator, call);
                    try forwarded_calls.append(allocator, .{ .request_index = request_index, .target = target });
                    dispatch_stats.recordForwardRequired();
                } else {
                    if (response_index >= output_messages.len) return error.InvalidTransition;
                    if (method_dispatch) {
                        try dispatchCallMethods(state, allocator, output_messages[response_index], call, call_context, call_dispatch);
                    } else {
                        try dispatchCall(state, allocator, output_messages[response_index], call, call_context, call_dispatch);
                    }
                    response_index += 1;
                    dispatch_stats.recordResponseInitialized();
                }
            },
            else => {
                if (observe_apply) {
                    try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                } else {
                    try state.applyWireMessage(allocator, request_message);
                }
                dispatch_stats.recordStateApplied();
            },
        }
    }

    const ready_handoffs = state.readyHandoffReturnStats();
    if (output_messages.len < response_index + ready_handoffs.total() + forwarded_calls.items.len) return error.InvalidTransition;
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        output_messages[response_index..][0..ready_handoffs.total()],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );

    var forward_index = response_index + handoff_stats.total();
    for (forwarded_calls.items) |forwarded_call| {
        try initForwardedWireCallMessage(
            output_messages[forward_index],
            try request_messages[forwarded_call.request_index].call(),
            forwarded_call.target,
        );
        forward_index += 1;
    }

    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingToDenseSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesForwardingToDenseSinks(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        response_context,
        response_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingDenseFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingDenseToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    return dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
        false,
        false,
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        {},
        ignoreInitializedMessage,
    );
}

pub fn dispatchRpcTurnForwardingUnifiedDenseToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    for (output_messages[0..turn_plan.totalOutputMessages()]) |message| {
        try queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    return dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
        false,
        true,
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchRpcTurnForwardingUnifiedDenseToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    for (output_messages[0..turn_plan.totalOutputMessages()]) |message| {
        try queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    turn_plan.pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo);
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    turn_plan.pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo);
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        disembargo_messages,
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        disembargo_messages,
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingToDenseSinksFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesToSink(
        disembargo_messages,
        disembargo_target,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingToDenseSinksFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(
        disembargo_messages,
        disembargo_target,
        embargo,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesForwardingToDenseSinksWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        apply_context,
        apply_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        response_context,
        response_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingDenseToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        disembargo_messages,
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        disembargo_messages,
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingToDenseSinksFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesToSink(
        disembargo_messages,
        disembargo_target,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingToDenseSinksFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(
        disembargo_messages,
        disembargo_target,
        embargo,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesMethodsForwardingToDenseSinks(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        response_context,
        response_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnMethodsForwardingDenseFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesMethodsForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnMethodsForwardingDenseToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    return dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
        true,
        false,
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        {},
        ignoreInitializedMessage,
    );
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    for (output_messages[0..turn_plan.totalOutputMessages()]) |message| {
        try queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    return dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
        true,
        true,
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    for (output_messages[0..turn_plan.totalOutputMessages()]) |message| {
        try queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    turn_plan.pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo);
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    turn_plan.pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo);
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        disembargo_messages,
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        disembargo_messages,
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesToSink(
        disembargo_messages,
        disembargo_target,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(
        disembargo_messages,
        disembargo_target,
        embargo,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesMethodsForwardingToDenseSinksWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        apply_context,
        apply_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        response_context,
        response_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnMethodsForwardingDenseToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        disembargo_messages,
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        disembargo_messages,
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesToSink(
        disembargo_messages,
        disembargo_target,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(
        disembargo_messages,
        disembargo_target,
        embargo,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnPendingAcceptDisembargosToSink(
    state: *const State,
    message_builders: anytype,
    target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoCount() };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesToSink(message_builders, target, sink_context, sink_handler);
}

pub fn dispatchRpcTurnPendingAcceptDisembargosToQueue(
    state: *const State,
    allocator: std.mem.Allocator,
    message_builders: anytype,
    target: CallTarget,
    queue: anytype,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoCount() };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesToQueue(allocator, message_builders, target, queue);
}

pub fn dispatchRpcTurnPendingAcceptDisembargos(
    state: *const State,
    message_builders: anytype,
    target: CallTarget,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoCount() };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessages(message_builders, target);
}

pub fn dispatchRpcTurnPendingAcceptDisembargosForEmbargoToSink(
    state: *const State,
    message_builders: anytype,
    target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo) };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesForEmbargoToSink(message_builders, target, embargo, sink_context, sink_handler);
}

pub fn dispatchRpcTurnPendingAcceptDisembargosForEmbargoToQueue(
    state: *const State,
    allocator: std.mem.Allocator,
    message_builders: anytype,
    target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo) };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesForEmbargoToQueue(allocator, message_builders, target, embargo, queue);
}

pub fn dispatchRpcTurnPendingAcceptDisembargosForEmbargo(
    state: *const State,
    message_builders: anytype,
    target: CallTarget,
    embargo: []const u8,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo) };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesForEmbargo(message_builders, target, embargo);
}

pub fn dispatchWireMessagesMethods(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsWithOutcomeHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsToSinkOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            response_context,
            response_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        if (outcome == .response_initialized) {
            try queue.append(allocator, response_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsToSinkOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            response_context,
            response_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        if (outcome == .response_initialized) {
            try queue.append(allocator, response_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsWithOutcomeHandlerAndApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToDenseSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    try state.applyWireCall(allocator, call);
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToDenseSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    try state.applyWireCall(allocator, call);
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsDense(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesMethodsToDenseSink(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        {},
        ignoreInitializedMessage,
    );
}

pub fn dispatchWireMessagesMethodsDenseToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsDense(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesMethodsToDenseSinkWithApplyHandler(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        {},
        ignoreInitializedMessage,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesMethodsDenseToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingToSinksOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToDenseSinks(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    try forward_handler(forward_context, forward_messages[forward_index]);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToDenseSinksWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    try forward_handler(forward_context, forward_messages[forward_index]);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingDense(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingDenseToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDense(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesMethodsDispatch(state, request_messages, call_entries);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    return dispatchWireMessagesMethodsForwardingDense(
        state,
        allocator,
        try planned.denseResponseRange().slice(output_messages),
        try planned.denseForwardRange().slice(output_messages),
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsForwardingUnifiedDense(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    for (output_messages[0..stats.denseOutputSlots()]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesMethodsDispatch(state, request_messages, call_entries);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    const response_messages = try planned.denseResponseRange().slice(output_messages);
    const forward_messages = try planned.denseForwardRange().slice(output_messages);
    const stats = try dispatchWireMessagesMethodsForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesMethodsDispatch(state, request_messages, call_entries);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    return dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        state,
        allocator,
        try planned.denseResponseRange().slice(output_messages),
        try planned.denseForwardRange().slice(output_messages),
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsForwardingUnifiedDenseWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    for (output_messages[0..stats.denseOutputSlots()]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesMethodsDispatch(state, request_messages, call_entries);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    const response_messages = try planned.denseResponseRange().slice(output_messages);
    const forward_messages = try planned.denseForwardRange().slice(output_messages);
    const stats = try dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesMethodsForwardingToDenseSinksWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        {},
        ignoreInitializedMessage,
        {},
        ignoreInitializedMessage,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesMethodsForwardingDenseToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwarding(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingWithOutcomeHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingToSinkOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            forward_context,
            forward_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        if (outcome == .forward_required) {
            try queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        if (outcome == .response_initialized) {
            try response_queue.append(allocator, response_messages[index]);
        } else if (outcome == .forward_required) {
            try forward_queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingToSinkOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            forward_context,
            forward_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        if (outcome == .forward_required) {
            try queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingWithOutcomeHandlerAndApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        if (outcome == .response_initialized) {
            try response_queue.append(allocator, response_messages[index]);
        } else if (outcome == .forward_required) {
            try forward_queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToSinksWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingToSinksOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn initWireHandoffReturnMessage(message: anytype, completion: HandoffReturn) !void {
    switch (completion) {
        .provide => |value| try initCapabilityReturnMessage(message, value.question_id, value.export_id),
        .accept => |value| try initCapabilityReturnMessage(message, value.question_id, value.export_id),
        .join => |value| try initWireJoinResultReturnMessage(message, value.question_id, true, 0, &.{.{ .sender_hosted = value.export_id }}),
    }
}

pub fn initWireHandoffReturnMessages(response_messages: anytype, completions: []const HandoffReturn) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToSink(
    response_messages: anytype,
    completions: []const HandoffReturn,
    sink_context: anytype,
    sink_handler: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        try sink_handler(sink_context, response_messages[index]);
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToTaggedSink(
    response_messages: anytype,
    completions: []const HandoffReturn,
    sink_context: anytype,
    sink_handler: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        const position = stats.nextPosition(completion);
        try initWireHandoffReturnMessage(response_messages[index], completion);
        try sink_handler(sink_context, position, response_messages[index]);
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToQueue(
    allocator: std.mem.Allocator,
    response_messages: anytype,
    completions: []const HandoffReturn,
    queue: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        try queue.append(allocator, response_messages[index]);
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToTaggedQueue(
    allocator: std.mem.Allocator,
    response_messages: anytype,
    completions: []const HandoffReturn,
    queue: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        const position = stats.nextPosition(completion);
        try initWireHandoffReturnMessage(response_messages[index], completion);
        try queue.append(allocator, .{ .position = position, .message = response_messages[index] });
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToSinks(
    response_messages: anytype,
    completions: []const HandoffReturn,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        switch (completion) {
            .provide => try provide_handler(provide_context, response_messages[index]),
            .accept => try accept_handler(accept_context, response_messages[index]),
            .join => try join_handler(join_context, response_messages[index]),
        }
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToQueues(
    allocator: std.mem.Allocator,
    response_messages: anytype,
    completions: []const HandoffReturn,
    provide_queue: anytype,
    accept_queue: anytype,
    join_queue: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        switch (completion) {
            .provide => try provide_queue.append(allocator, response_messages[index]),
            .accept => try accept_queue.append(allocator, response_messages[index]),
            .join => try join_queue.append(allocator, response_messages[index]),
        }
        stats.record(completion);
    }
    return stats;
}

pub fn initWireFinish(finish: anytype, value: Finish) !void {
    try finish.set_questionId(value.question_id);
    try finish.set_releaseResultCaps(value.release_result_caps);
}

pub fn initWireFinishMessage(message: anytype, value: Finish) !void {
    try initWireFinish(try message.init_finish(), value);
}

pub fn initWireRelease(release: anytype, value: CapabilityRelease) !void {
    try release.set_id(value.id);
    try release.set_referenceCount(value.reference_count);
}

pub fn initWireReleaseMessage(message: anytype, value: CapabilityRelease) !void {
    try initWireRelease(try message.init_release(), value);
}

pub fn initWireCallParamsCapTable(call: anytype, descriptors: []const CapDescriptor) !void {
    try initWirePayloadCapTable(try call.init_params(), descriptors);
}

pub fn initWireCallParamsCapTableInfo(call: anytype, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadCapTableInfo(try call.init_params(), infos);
}

pub fn initWireCallParamsCapability(call: anytype, capability_index: u32, descriptors: []const CapDescriptor) !void {
    try initWirePayloadCapability(try call.init_params(), capability_index, descriptors);
}

pub fn initWireCallParamsCapabilityInfo(call: anytype, capability_index: u32, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadCapabilityInfo(try call.init_params(), capability_index, infos);
}

pub fn initWireCallParamsCapabilityFromRegistry(allocator: std.mem.Allocator, call: anytype, capability_index: u32, registry: anytype) !void {
    try initWirePayloadCapabilityFromRegistry(allocator, try call.init_params(), capability_index, registry);
}

pub fn initWireCallParamsStructWith(
    call: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructWith(try call.init_params(), struct_size, descriptors, context, fill);
}

pub fn initWireCallParamsStructInfoWith(
    call: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructInfoWith(try call.init_params(), struct_size, infos, context, fill);
}

pub fn initWireCallParamsStructFromRegistry(
    allocator: std.mem.Allocator,
    call: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructFromRegistry(allocator, try call.init_params(), struct_size, registry, context, fill);
}

pub fn initWireCallParamsText(call: anytype, text: []const u8, descriptors: []const CapDescriptor) !void {
    try initWirePayloadText(try call.init_params(), text, descriptors);
}

pub fn initWireCallParamsData(call: anytype, data: []const u8, descriptors: []const CapDescriptor) !void {
    try initWirePayloadData(try call.init_params(), data, descriptors);
}

pub fn initWireCallParamsUInt32List(call: anytype, values: []const u32, descriptors: []const CapDescriptor) !void {
    try initWirePayloadUInt32List(try call.init_params(), values, descriptors);
}

pub fn initWireCallParamsTextInfo(call: anytype, text: []const u8, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadTextInfo(try call.init_params(), text, infos);
}

pub fn initWireCallParamsDataInfo(call: anytype, data: []const u8, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadDataInfo(try call.init_params(), data, infos);
}

pub fn initWireCallParamsUInt32ListInfo(call: anytype, values: []const u32, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadUInt32ListInfo(try call.init_params(), values, infos);
}

pub fn initWireCallParamsTextFromRegistry(allocator: std.mem.Allocator, call: anytype, text: []const u8, registry: anytype) !void {
    try initWirePayloadTextFromRegistry(allocator, try call.init_params(), text, registry);
}

pub fn initWireCallParamsDataFromRegistry(allocator: std.mem.Allocator, call: anytype, data: []const u8, registry: anytype) !void {
    try initWirePayloadDataFromRegistry(allocator, try call.init_params(), data, registry);
}

pub fn initWireCallParamsUInt32ListFromRegistry(allocator: std.mem.Allocator, call: anytype, values: []const u32, registry: anytype) !void {
    try initWirePayloadUInt32ListFromRegistry(allocator, try call.init_params(), values, registry);
}

pub fn initWireReturnResultsCapTable(return_: anytype, descriptors: []const CapDescriptor) !void {
    try initWirePayloadCapTable(try return_.init_results(), descriptors);
}

pub fn initWireReturnResultsCapTableInfo(return_: anytype, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadCapTableInfo(try return_.init_results(), infos);
}

pub fn initWireReturnResultsCapability(return_: anytype, capability_index: u32, descriptors: []const CapDescriptor) !void {
    try initWirePayloadCapability(try return_.init_results(), capability_index, descriptors);
}

pub fn initWireReturnResultsCapabilityInfo(return_: anytype, capability_index: u32, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadCapabilityInfo(try return_.init_results(), capability_index, infos);
}

pub fn initWireReturnResultsCapabilityFromRegistry(allocator: std.mem.Allocator, return_: anytype, capability_index: u32, registry: anytype) !void {
    try initWirePayloadCapabilityFromRegistry(allocator, try return_.init_results(), capability_index, registry);
}

pub fn initWireReturnResultsStructWith(
    return_: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructWith(try return_.init_results(), struct_size, descriptors, context, fill);
}

pub fn initWireReturnResultsStructInfoWith(
    return_: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructInfoWith(try return_.init_results(), struct_size, infos, context, fill);
}

pub fn initWireReturnResultsStructFromRegistry(
    allocator: std.mem.Allocator,
    return_: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructFromRegistry(allocator, try return_.init_results(), struct_size, registry, context, fill);
}

pub fn initWireReturnResultsText(return_: anytype, text: []const u8, descriptors: []const CapDescriptor) !void {
    try initWirePayloadText(try return_.init_results(), text, descriptors);
}

pub fn initWireReturnResultsData(return_: anytype, data: []const u8, descriptors: []const CapDescriptor) !void {
    try initWirePayloadData(try return_.init_results(), data, descriptors);
}

pub fn initWireReturnResultsUInt32List(return_: anytype, values: []const u32, descriptors: []const CapDescriptor) !void {
    try initWirePayloadUInt32List(try return_.init_results(), values, descriptors);
}

pub fn initWireReturnResultsTextInfo(return_: anytype, text: []const u8, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadTextInfo(try return_.init_results(), text, infos);
}

pub fn initWireReturnResultsDataInfo(return_: anytype, data: []const u8, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadDataInfo(try return_.init_results(), data, infos);
}

pub fn initWireReturnResultsUInt32ListInfo(return_: anytype, values: []const u32, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadUInt32ListInfo(try return_.init_results(), values, infos);
}

pub fn initWireReturnResultsTextFromRegistry(allocator: std.mem.Allocator, return_: anytype, text: []const u8, registry: anytype) !void {
    try initWirePayloadTextFromRegistry(allocator, try return_.init_results(), text, registry);
}

pub fn initWireReturnResultsDataFromRegistry(allocator: std.mem.Allocator, return_: anytype, data: []const u8, registry: anytype) !void {
    try initWirePayloadDataFromRegistry(allocator, try return_.init_results(), data, registry);
}

pub fn initWireReturnResultsUInt32ListFromRegistry(allocator: std.mem.Allocator, return_: anytype, values: []const u32, registry: anytype) !void {
    try initWirePayloadUInt32ListFromRegistry(allocator, try return_.init_results(), values, registry);
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

pub fn capTableInfoFromWirePayload(allocator: std.mem.Allocator, payload: anytype) ![]CapDescriptorInfo {
    const cap_table = payload.capTable() catch |err| switch (err) {
        error.NullPointer => return allocator.alloc(CapDescriptorInfo, 0),
        else => return err,
    };
    const infos = try allocator.alloc(CapDescriptorInfo, cap_table.len());
    errdefer allocator.free(infos);
    for (infos, 0..) |*info, index| {
        info.* = try capDescriptorInfoFromWire(try cap_table.get(index));
    }
    return infos;
}

pub fn capTableFromWireCallParams(allocator: std.mem.Allocator, call: anytype) ![]CapDescriptor {
    return capTableFromWirePayload(allocator, try call.params());
}

pub fn capTableInfoFromWireCallParams(allocator: std.mem.Allocator, call: anytype) ![]CapDescriptorInfo {
    return capTableInfoFromWirePayload(allocator, try call.params());
}

pub fn capTableFromWireReturnResults(allocator: std.mem.Allocator, return_: anytype) ![]CapDescriptor {
    return capTableFromWirePayload(allocator, try return_.results());
}

pub fn capTableInfoFromWireReturnResults(allocator: std.mem.Allocator, return_: anytype) ![]CapDescriptorInfo {
    return capTableInfoFromWirePayload(allocator, try return_.results());
}

pub fn payloadContentCapabilityIndex(payload: anytype) !?u32 {
    return (try payload.content()).getCapabilityIndex() catch |err| switch (err) {
        error.InvalidPointerKind, error.NullPointer => null,
        else => return err,
    };
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

pub fn writeAbortInfoToWire(info: ExceptionInfo, abort: anytype) !void {
    try writeExceptionInfoToWire(info, abort);
}

pub fn initWireAbortMessage(message: anytype, info: ExceptionInfo) !void {
    try writeAbortInfoToWire(info, try message.init_abort());
}

pub fn initWireUnimplementedMessage(message: anytype) !void {
    _ = try message.init_unimplemented();
}

pub fn initWireUnimplementedMessageFrom(message: anytype, original: anytype) !void {
    try message.set_unimplemented_from(original);
}

pub fn initWireUnimplementedMessageFromBuilder(message: anytype, original: anytype) !void {
    try message.set_unimplemented_fromBuilder(original);
}

pub fn initWireObsoleteSaveMessage(message: anytype) !void {
    try message.set_obsoleteSave();
}

pub fn initWireObsoleteDeleteMessage(message: anytype) !void {
    try message.set_obsoleteDelete();
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

fn capDescriptorImportIdsAlloc(allocator: std.mem.Allocator, descriptors: []const CapDescriptor) std.mem.Allocator.Error![]ImportId {
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

fn validateWirePayloadContent(payload: anytype, cap_count: usize) !void {
    const content = try payload.content();
    _ = try content.validateWithOptions(.{ .capability_count_limit = cap_count });
}

pub fn validateWirePayload(allocator: std.mem.Allocator, payload: anytype) !void {
    const descriptors = try capTableFromWirePayload(allocator, payload);
    defer allocator.free(descriptors);
    try validateWirePayloadContent(payload, descriptors.len);
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

pub const State = struct {
    allocator: std.mem.Allocator,
    questions: std.AutoHashMap(QuestionId, QuestionTracker),
    answers: std.AutoHashMap(AnswerId, AnswerTracker),
    exports: std.AutoHashMap(ExportId, ExportTracker),
    imports: std.AutoHashMap(ImportId, ImportTracker),
    param_imports: std.AutoHashMap(QuestionId, []ImportId),
    result_imports: std.AutoHashMap(AnswerId, []ImportId),
    accepts: std.AutoHashMap(QuestionId, AcceptTracker),
    joins: std.AutoHashMap(QuestionId, JoinTracker),
    provides: std.AutoHashMap(QuestionId, ProvideTracker),
    calls: std.AutoHashMap(QuestionId, CallInfo),

    pub fn init(allocator: std.mem.Allocator) State {
        return .{
            .allocator = allocator,
            .questions = std.AutoHashMap(QuestionId, QuestionTracker).init(allocator),
            .answers = std.AutoHashMap(AnswerId, AnswerTracker).init(allocator),
            .exports = std.AutoHashMap(ExportId, ExportTracker).init(allocator),
            .imports = std.AutoHashMap(ImportId, ImportTracker).init(allocator),
            .param_imports = std.AutoHashMap(QuestionId, []ImportId).init(allocator),
            .result_imports = std.AutoHashMap(AnswerId, []ImportId).init(allocator),
            .accepts = std.AutoHashMap(QuestionId, AcceptTracker).init(allocator),
            .joins = std.AutoHashMap(QuestionId, JoinTracker).init(allocator),
            .provides = std.AutoHashMap(QuestionId, ProvideTracker).init(allocator),
            .calls = std.AutoHashMap(QuestionId, CallInfo).init(allocator),
        };
    }

    pub fn deinit(self: *State) void {
        self.calls.deinit();
        self.provides.deinit();
        self.joins.deinit();
        var accepts = self.accepts.valueIterator();
        while (accepts.next()) |accept| accept.deinit(self.allocator);
        self.accepts.deinit();
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

    fn clearAccept(self: *State, id: QuestionId) void {
        if (self.accepts.fetchRemove(id)) |entry| {
            var tracker = entry.value;
            tracker.deinit(self.allocator);
        }
    }

    fn clearJoin(self: *State, id: QuestionId) void {
        _ = self.joins.remove(id);
    }

    fn clearProvide(self: *State, id: QuestionId) void {
        _ = self.provides.remove(id);
    }

    fn clearCallInfo(self: *State, id: QuestionId) void {
        _ = self.calls.remove(id);
    }

    pub fn questionComplete(self: *const State, id: QuestionId) bool {
        const question = self.questions.get(id) orelse return false;
        const answer = self.answers.get(id) orelse return false;
        return question.state == .finished and answer.state == .resolved;
    }

    pub fn questionReadyToForget(self: *const State, id: QuestionId) bool {
        return self.questionComplete(id);
    }

    pub fn answerComplete(self: *const State, id: AnswerId) bool {
        const answer = self.answers.get(id) orelse return false;
        return answer.state == .resolved;
    }

    pub fn questionStats(self: *const State) StateQuestionStats {
        var stats = StateQuestionStats{
            .questions = self.questions.count(),
            .answers = self.answers.count(),
        };
        var questions = self.questions.iterator();
        while (questions.next()) |entry| {
            switch (entry.value_ptr.state) {
                .idle => {},
                .open => stats.open_questions += 1,
                .finished => stats.finished_questions += 1,
            }
            if (self.questionComplete(entry.key_ptr.*)) stats.complete_questions += 1;
        }
        var answers = self.answers.valueIterator();
        while (answers.next()) |answer| {
            switch (answer.state) {
                .unresolved => stats.unresolved_answers += 1,
                .resolved => stats.resolved_answers += 1,
            }
        }
        return stats;
    }

    pub fn canReuseQuestionId(self: *const State, id: QuestionId) bool {
        return (!self.questions.contains(id) and !self.answers.contains(id)) or self.questionComplete(id);
    }

    pub fn forgetQuestion(self: *State, id: QuestionId) Error!void {
        if (!self.questions.contains(id) and !self.answers.contains(id)) return error.QuestionNotOpen;
        if (!self.questionReadyToForget(id)) return error.InvalidTransition;
        self.clearParamImports(id);
        self.clearResultImports(id);
        self.clearAccept(id);
        self.clearJoin(id);
        self.clearProvide(id);
        _ = self.questions.remove(id);
        _ = self.answers.remove(id);
    }

    pub fn forgetCompletedQuestions(self: *State) usize {
        var removed: usize = 0;
        while (true) {
            var ready_id: ?QuestionId = null;
            var iterator = self.questions.iterator();
            while (iterator.next()) |entry| {
                const id = entry.key_ptr.*;
                if (self.questionReadyToForget(id)) {
                    ready_id = id;
                    break;
                }
            }
            const id = ready_id orelse return removed;
            self.forgetQuestion(id) catch unreachable;
            removed += 1;
        }
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
            self.clearAccept(id);
            self.clearJoin(id);
            self.clearProvide(id);
            self.clearCallInfo(id);
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
        self.clearAccept(id);
        self.clearJoin(id);
        self.clearProvide(id);
        self.clearCallInfo(id);
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
            .none, .sender_hosted, .sender_promise, .third_party_hosted => {},
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
            .third_party_hosted => |id| self.receiveImport(id),
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

    fn validateTrackedImports(self: *const State, ids: []const ImportId) Error!void {
        for (ids) |id| {
            const tracker = self.imports.get(id) orelse return error.InvalidTransition;
            if (tracker.state != .live) return error.ImportAlreadyReleased;
        }
    }

    fn validateParamImports(self: *const State, question_id: QuestionId) Error!void {
        const ids = self.param_imports.get(question_id) orelse return;
        try self.validateTrackedImports(ids);
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

    fn validateResultImports(self: *const State, answer_id: AnswerId) Error!void {
        const ids = self.result_imports.get(answer_id) orelse return;
        try self.validateTrackedImports(ids);
    }

    fn trackAccept(self: *State, info: AcceptInfo) std.mem.Allocator.Error!void {
        const embargo = if (info.embargo) |bytes| try self.allocator.dupe(u8, bytes) else null;
        errdefer if (embargo) |bytes| self.allocator.free(bytes);

        if (self.accepts.fetchRemove(info.question_id)) |old| {
            var tracker = old.value;
            tracker.deinit(self.allocator);
        }
        try self.accepts.put(info.question_id, .{
            .question_id = info.question_id,
            .has_provision = info.has_provision,
            .provision = if (info.has_provision) .{
                .max_capability_count = info.provision_max_capability_count,
                .capability = info.provision_capability,
            } else null,
            .embargo = embargo,
        });
    }

    fn trackJoin(self: *State, info: JoinInfo) std.mem.Allocator.Error!void {
        _ = self.joins.remove(info.question_id);
        try self.joins.put(info.question_id, .{
            .question_id = info.question_id,
            .target = info.target,
            .has_key_part = info.has_key_part,
            .key_part = if (info.has_key_part) .{
                .max_capability_count = info.key_part_max_capability_count,
                .capability = info.key_part_capability,
            } else null,
        });
    }

    fn trackProvide(self: *State, info: ProvideInfo) std.mem.Allocator.Error!void {
        _ = self.provides.remove(info.question_id);
        try self.provides.put(info.question_id, .{
            .question_id = info.question_id,
            .target = info.target,
            .has_recipient = info.has_recipient,
            .recipient = if (info.has_recipient) .{
                .max_capability_count = info.recipient_max_capability_count,
                .capability = info.recipient_capability,
            } else null,
        });
    }

    fn trackCallInfo(self: *State, info: CallInfo) std.mem.Allocator.Error!void {
        _ = self.calls.remove(info.question_id);
        try self.calls.put(info.question_id, info);
    }

    fn markAcceptedEmbargoReleased(self: *State, embargo: []const u8) usize {
        var released: usize = 0;
        var iterator = self.accepts.valueIterator();
        while (iterator.next()) |accept| {
            if (accept.embargo) |tracked| {
                if (!accept.embargo_released and std.mem.eql(u8, tracked, embargo)) {
                    accept.embargo_released = true;
                    released += 1;
                }
            }
        }
        return released;
    }

    fn markAcceptedEmbargoReleasedAlloc(self: *State, allocator: std.mem.Allocator, embargo: []const u8) std.mem.Allocator.Error![]QuestionId {
        var ids = std.ArrayList(QuestionId).empty;
        errdefer ids.deinit(allocator);
        var iterator = self.accepts.iterator();
        while (iterator.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.embargo) |tracked| {
                if (!accept.embargo_released and std.mem.eql(u8, tracked, embargo)) {
                    accept.embargo_released = true;
                    try ids.append(allocator, entry.key_ptr.*);
                }
            }
        }
        return ids.toOwnedSlice(allocator);
    }

    fn applyDisembargoInfo(self: *State, info: DisembargoInfo) Error!DisembargoApplyInfo {
        try self.validateCallTarget(info.target);
        const released_accepts = switch (info.context) {
            .accept => |embargo| self.markAcceptedEmbargoReleased(embargo),
            else => 0,
        };
        return .{ .released_accepts = released_accepts };
    }

    fn applyDisembargoInfoAlloc(self: *State, allocator: std.mem.Allocator, info: DisembargoInfo) (Error || std.mem.Allocator.Error)!DisembargoApplyInfo {
        try self.validateCallTarget(info.target);
        const released_accept_ids: []QuestionId = switch (info.context) {
            .accept => |embargo| try self.markAcceptedEmbargoReleasedAlloc(allocator, embargo),
            else => try allocator.alloc(QuestionId, 0),
        };
        return .{ .released_accepts = released_accept_ids.len, .released_accept_ids = released_accept_ids };
    }

    pub fn applyWireCallPayload(self: *State, allocator: std.mem.Allocator, call: anytype) !void {
        const descriptors = try capTableFromWireCallParams(allocator, call);
        defer allocator.free(descriptors);
        try validateWirePayloadContent(try call.params(), descriptors.len);
        try self.applyCapTable(descriptors);
    }

    pub fn applyWireReturnPayload(self: *State, allocator: std.mem.Allocator, return_: anytype) !void {
        const descriptors = try capTableFromWireReturnResults(allocator, return_);
        defer allocator.free(descriptors);
        try validateWirePayloadContent(try return_.results(), descriptors.len);
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

    pub fn callTargetResolution(self: *const State, target: CallTarget) ?CapDescriptor {
        return switch (target) {
            .imported_cap => |id| self.importResolution(id),
            .promised_answer => null,
        };
    }

    pub fn callTargetResolved(self: *const State, target: CallTarget) bool {
        return self.callTargetResolution(target) != null;
    }

    pub fn callTargetForwardTarget(self: *const State, target: CallTarget) ?CallTarget {
        const resolution = self.callTargetResolution(target) orelse return null;
        return callTargetFromForwardableCapDescriptor(resolution);
    }

    pub fn callTargetFinalResolution(self: *const State, target: CallTarget) Error!?CapDescriptor {
        var current = target;
        var final_resolution: ?CapDescriptor = null;
        var remaining = self.imports.count() + 1;
        while (remaining != 0) : (remaining -= 1) {
            const resolution = self.callTargetResolution(current) orelse return final_resolution;
            final_resolution = resolution;
            current = callTargetFromForwardableCapDescriptor(resolution) orelse return final_resolution;
        }
        return error.InvalidTransition;
    }

    pub fn callTargetTransitiveForwardTarget(self: *const State, target: CallTarget) Error!?CallTarget {
        const final_resolution = (try self.callTargetFinalResolution(target)) orelse return null;
        return callTargetFromForwardableCapDescriptor(final_resolution);
    }

    pub fn effectiveCallTarget(self: *const State, target: CallTarget) CallTarget {
        return self.callTargetForwardTarget(target) orelse target;
    }

    pub fn transitiveEffectiveCallTarget(self: *const State, target: CallTarget) Error!CallTarget {
        return (try self.callTargetTransitiveForwardTarget(target)) orelse target;
    }

    pub fn wireCallTargetResolution(self: *const State, call: anytype) !?CapDescriptor {
        return self.callTargetResolution(try callTargetFromWireCall(call));
    }

    pub fn wireCallTargetFinalResolution(self: *const State, call: anytype) !?CapDescriptor {
        return try self.callTargetFinalResolution(try callTargetFromWireCall(call));
    }

    pub fn wireCallTargetResolved(self: *const State, call: anytype) !bool {
        return self.callTargetResolved(try callTargetFromWireCall(call));
    }

    pub fn wireCallTargetForwardTarget(self: *const State, call: anytype) !?CallTarget {
        return self.callTargetForwardTarget(try callTargetFromWireCall(call));
    }

    pub fn wireCallTargetTransitiveForwardTarget(self: *const State, call: anytype) !?CallTarget {
        return try self.callTargetTransitiveForwardTarget(try callTargetFromWireCall(call));
    }

    pub fn effectiveWireCallTarget(self: *const State, call: anytype) !CallTarget {
        return self.effectiveCallTarget(try callTargetFromWireCall(call));
    }

    pub fn transitiveEffectiveWireCallTarget(self: *const State, call: anytype) !CallTarget {
        return try self.transitiveEffectiveCallTarget(try callTargetFromWireCall(call));
    }

    pub fn validateWireDisembargo(self: *const State, disembargo: anytype) !void {
        const info = try disembargoInfoFromWireDisembargo(disembargo);
        try self.validateCallTarget(info.target);
    }

    pub fn applyDisembargo(self: *State, info: DisembargoInfo) Error!DisembargoApplyInfo {
        return self.applyDisembargoInfo(info);
    }

    pub fn applyWireDisembargo(self: *State, disembargo: anytype) !DisembargoApplyInfo {
        return self.applyDisembargoInfo(try disembargoInfoFromWireDisembargo(disembargo));
    }

    pub fn applyDisembargoAlloc(self: *State, allocator: std.mem.Allocator, info: DisembargoInfo) (Error || std.mem.Allocator.Error)!DisembargoApplyInfo {
        return self.applyDisembargoInfoAlloc(allocator, info);
    }

    pub fn applyWireDisembargoAlloc(self: *State, allocator: std.mem.Allocator, disembargo: anytype) !DisembargoApplyInfo {
        return self.applyDisembargoInfoAlloc(allocator, try disembargoInfoFromWireDisembargo(disembargo));
    }

    pub fn applyWireCall(self: *State, allocator: std.mem.Allocator, call: anytype) !void {
        const question_id = call.questionId();
        const target = try callTargetFromWireCall(call);
        const options = try callOptionsFromWireCall(call);
        const descriptors = try capTableFromWireCallParams(allocator, call);
        defer allocator.free(descriptors);

        try self.validateCallTarget(target);
        try validateWirePayloadContent(try call.params(), descriptors.len);
        for (descriptors) |descriptor| try self.validateCapDescriptor(descriptor);
        try self.openQuestion(question_id, .call);
        try self.trackCallInfo(options.callInfo(question_id, target));
        for (descriptors) |descriptor| try self.applyCapDescriptor(descriptor);
        try self.trackParamImports(question_id, descriptors);
    }

    pub fn applyWireReturn(self: *State, allocator: std.mem.Allocator, return_: anytype) !void {
        const answer_id = return_.answerId();
        const release_param_caps = return_.releaseParamCaps();
        const no_finish_needed = return_.noFinishNeeded();
        const outcome = try returnOutcomeFromWireReturn(return_);
        if (outcome == .take_from_other_question and !self.answers.contains(outcome.take_from_other_question)) return error.QuestionNotOpen;

        var allocated_descriptors: ?[]CapDescriptor = null;
        defer if (allocated_descriptors) |descriptors| allocator.free(descriptors);
        const descriptors: []const CapDescriptor = switch (outcome) {
            .results => blk: {
                const result_descriptors = try capTableFromWireReturnResults(allocator, return_);
                allocated_descriptors = result_descriptors;
                try validateWirePayloadContent(try return_.results(), result_descriptors.len);
                break :blk result_descriptors;
            },
            .exception, .canceled, .results_sent_elsewhere, .take_from_other_question, .await_from_third_party => &.{},
        };

        for (descriptors) |descriptor| try self.validateCapDescriptor(descriptor);
        if (release_param_caps) try self.validateParamImports(answer_id);
        try self.resolveAnswer(answer_id, .return_);
        for (descriptors) |descriptor| try self.applyCapDescriptor(descriptor);
        try self.trackResultImports(answer_id, descriptors);
        if (release_param_caps) try self.releaseParamImports(answer_id);
        if (no_finish_needed and descriptors.len == 0) {
            try self.finishQuestion(answer_id);
        }
    }

    pub fn applyWireResolve(self: *State, resolve: anytype) !void {
        const info = try resolveInfoFromWireResolve(resolve);
        if (info.cap) |descriptor| try self.validateCapDescriptor(descriptor);
        if (self.imports.contains(info.promise_id)) {
            try self.resolveImportTo(info.promise_id, info.cap);
        } else {
            try self.resolveExportTo(info.promise_id, info.cap);
        }
        if (info.cap) |descriptor| try self.applyCapDescriptor(descriptor);
    }

    pub fn applyWireTargetedQuestion(self: *State, question_id: QuestionId, targeted: anytype) !void {
        try self.validateCallTarget(try targetFromWireTargetedMessage(targeted));
        try self.openQuestion(question_id, .call);
    }

    pub fn applyWireProvide(self: *State, provide: anytype) !void {
        const info = try provideInfoFromWireProvide(provide);
        try self.validateCallTarget(info.target);
        try self.openQuestion(info.question_id, .call);
        try self.trackProvide(info);
    }

    pub fn applyWireAccept(self: *State, accept: anytype) !void {
        const info = try acceptInfoFromWireAccept(accept);
        try self.openQuestion(info.question_id, .call);
        try self.trackAccept(info);
    }

    pub fn applyWireJoin(self: *State, join: anytype) !void {
        const info = try joinInfoFromWireJoin(join);
        try self.validateCallTarget(info.target);
        try self.openQuestion(info.question_id, .call);
        try self.trackJoin(info);
    }

    pub fn applyWireMessage(self: *State, allocator: std.mem.Allocator, message: anytype) !void {
        const event = try eventFromWireMessage(message);
        return switch (event) {
            .call => self.applyWireCall(allocator, try message.call()),
            .return_ => self.applyWireReturn(allocator, try message.return_()),
            .resolve => self.applyWireResolve(try message.resolve()),
            .disembargo => {
                _ = try self.applyWireDisembargo(try message.disembargo());
            },
            .provide => self.applyWireProvide(try message.provide()),
            .accept => self.applyWireAccept(try message.accept()),
            .join => self.applyWireJoin(try message.join()),
            else => self.applyWireEvent(event),
        };
    }

    pub fn applyWireMessageAlloc(self: *State, allocator: std.mem.Allocator, message: anytype) !WireMessageApplyResult {
        const event = try eventFromWireMessage(message);
        switch (event) {
            .call => try self.applyWireCall(allocator, try message.call()),
            .return_ => try self.applyWireReturn(allocator, try message.return_()),
            .resolve => try self.applyWireResolve(try message.resolve()),
            .disembargo => return .{ .disembargo = try self.applyWireDisembargoAlloc(allocator, try message.disembargo()) },
            .provide => try self.applyWireProvide(try message.provide()),
            .accept => try self.applyWireAccept(try message.accept()),
            .join => try self.applyWireJoin(try message.join()),
            else => try self.applyWireEvent(event),
        }
        return .state_applied;
    }

    pub fn applyWireMessages(self: *State, allocator: std.mem.Allocator, messages: anytype) !usize {
        var applied: usize = 0;
        for (messages) |message| {
            try self.applyWireMessage(allocator, message);
            applied += 1;
        }
        return applied;
    }

    pub fn applyWireMessagesWithHandler(self: *State, allocator: std.mem.Allocator, messages: anytype, context: anytype, handler: anytype) !usize {
        var applied: usize = 0;
        for (messages) |message| {
            try self.applyWireMessage(allocator, message);
            try handler(context, message);
            applied += 1;
        }
        return applied;
    }

    pub fn applyWireMessagesAlloc(self: *State, allocator: std.mem.Allocator, messages: anytype) !WireMessageApplyStats {
        var stats: WireMessageApplyStats = .{};
        for (messages) |message| {
            var result = try self.applyWireMessageAlloc(allocator, message);
            stats.record(result);
            result.deinit(allocator);
        }
        return stats;
    }

    pub fn applyWireMessagesAllocWithHandler(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        context: anytype,
        handler: anytype,
    ) !WireMessageApplyStats {
        var stats: WireMessageApplyStats = .{};
        for (messages) |message| {
            var result = try self.applyWireMessageAlloc(allocator, message);
            errdefer result.deinit(allocator);
            stats.record(result);
            try handler(context, result);
            result.deinit(allocator);
        }
        return stats;
    }

    pub fn applyWireFinish(self: *State, finish: Finish) Error!void {
        if (finish.release_result_caps) try self.validateResultImports(finish.question_id);
        try self.finishQuestion(finish.question_id);
        if (finish.release_result_caps) try self.releaseResultImports(finish.question_id);
    }

    pub fn releaseExport(self: *State, id: ExportId) Error!void {
        const tracker = self.exports.getPtr(id) orelse return error.InvalidTransition;
        try tracker.release();
    }

    pub fn forgetReleasedExport(self: *State, id: ExportId) Error!void {
        const tracker = self.exports.get(id) orelse return error.InvalidTransition;
        if (tracker.state != .released) return error.InvalidTransition;
        _ = self.exports.remove(id);
    }

    pub fn resolveExport(self: *State, id: ExportId) Error!void {
        try self.resolveExportTo(id, null);
    }

    pub fn resolveExportTo(self: *State, id: ExportId, resolution: ?CapDescriptor) Error!void {
        const tracker = self.exports.getPtr(id) orelse return error.InvalidTransition;
        try tracker.resolveTo(resolution);
    }

    pub fn resolveImportTo(self: *State, id: ImportId, resolution: ?CapDescriptor) Error!void {
        const tracker = self.imports.getPtr(id) orelse return error.InvalidTransition;
        try tracker.resolveTo(resolution);
    }

    pub fn releaseImport(self: *State, id: ImportId) Error!void {
        const tracker = self.imports.getPtr(id) orelse return error.InvalidTransition;
        try tracker.release();
    }

    pub fn forgetReleasedImport(self: *State, id: ImportId) Error!void {
        const tracker = self.imports.get(id) orelse return error.InvalidTransition;
        if (tracker.state != .released) return error.InvalidTransition;
        _ = self.imports.remove(id);
    }

    pub fn forgetReleasedExports(self: *State) usize {
        var removed: usize = 0;
        while (true) {
            var released_id: ?ExportId = null;
            var iterator = self.exports.iterator();
            while (iterator.next()) |entry| {
                if (entry.value_ptr.state == .released) {
                    released_id = entry.key_ptr.*;
                    break;
                }
            }
            const id = released_id orelse return removed;
            _ = self.exports.remove(id);
            removed += 1;
        }
    }

    pub fn forgetReleasedImports(self: *State) usize {
        var removed: usize = 0;
        while (true) {
            var released_id: ?ImportId = null;
            var iterator = self.imports.iterator();
            while (iterator.next()) |entry| {
                if (entry.value_ptr.state == .released) {
                    released_id = entry.key_ptr.*;
                    break;
                }
            }
            const id = released_id orelse return removed;
            _ = self.imports.remove(id);
            removed += 1;
        }
    }

    pub fn forgetReleasedCapabilities(self: *State) struct { exports: usize, imports: usize } {
        return .{
            .exports = self.forgetReleasedExports(),
            .imports = self.forgetReleasedImports(),
        };
    }

    pub fn cleanup(self: *State) StateCleanupStats {
        const capabilities = self.forgetReleasedCapabilities();
        return .{
            .questions = self.forgetCompletedQuestions(),
            .exports = capabilities.exports,
            .imports = capabilities.imports,
        };
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

    pub fn questionKind(self: *const State, id: QuestionId) ?MessageKind {
        const question = self.questions.get(id) orelse return null;
        return question.kind;
    }

    pub fn answerState(self: *const State, id: AnswerId) ?AnswerState {
        const answer = self.answers.get(id) orelse return null;
        return answer.state;
    }

    pub fn answerKind(self: *const State, id: AnswerId) ?MessageKind {
        const answer = self.answers.get(id) orelse return null;
        return answer.kind;
    }

    pub fn exportState(self: *const State, id: ExportId) ?CapabilityLifetime {
        const tracker = self.exports.get(id) orelse return null;
        return tracker.state;
    }

    pub fn exportResolved(self: *const State, id: ExportId) ?bool {
        const tracker = self.exports.get(id) orelse return null;
        return tracker.resolved;
    }

    pub fn exportResolution(self: *const State, id: ExportId) ?CapDescriptor {
        const tracker = self.exports.get(id) orelse return null;
        return tracker.resolution;
    }

    pub fn importState(self: *const State, id: ImportId) ?CapabilityLifetime {
        const tracker = self.imports.get(id) orelse return null;
        return tracker.state;
    }

    pub fn importReferenceCount(self: *const State, id: ImportId) ?u32 {
        const tracker = self.imports.get(id) orelse return null;
        return tracker.reference_count;
    }

    pub fn capabilityStats(self: *const State) StateCapabilityStats {
        var stats = StateCapabilityStats{
            .exports = self.exports.count(),
            .imports = self.imports.count(),
        };
        var exports = self.exports.valueIterator();
        while (exports.next()) |export_tracker| {
            switch (export_tracker.state) {
                .live => stats.live_exports += 1,
                .released => stats.released_exports += 1,
            }
            if (export_tracker.resolved) stats.resolved_exports += 1;
        }
        var imports = self.imports.valueIterator();
        while (imports.next()) |import_tracker| {
            switch (import_tracker.state) {
                .live => stats.live_imports += 1,
                .released => stats.released_imports += 1,
            }
            if (import_tracker.resolved) stats.resolved_imports += 1;
            stats.import_references += import_tracker.reference_count;
        }
        return stats;
    }

    pub fn importResolved(self: *const State, id: ImportId) ?bool {
        const tracker = self.imports.get(id) orelse return null;
        return tracker.resolved;
    }

    pub fn importResolution(self: *const State, id: ImportId) ?CapDescriptor {
        const tracker = self.imports.get(id) orelse return null;
        return tracker.resolution;
    }

    pub fn acceptInfo(self: *const State, id: QuestionId) ?AcceptInfo {
        const tracker = self.accepts.get(id) orelse return null;
        return tracker.info();
    }

    pub fn acceptHasProvisionUsage(self: *const State, id: QuestionId) ?bool {
        const tracker = self.accepts.get(id) orelse return null;
        return tracker.hasProvisionUsage();
    }

    pub fn acceptProvisionMatchesCapability(self: *const State, id: QuestionId, capability_index: u32) ?bool {
        const tracker = self.accepts.get(id) orelse return null;
        return tracker.provisionMatchesCapability(capability_index);
    }

    pub fn acceptHasEmbargo(self: *const State, id: QuestionId) ?bool {
        const tracker = self.accepts.get(id) orelse return null;
        return tracker.hasEmbargo();
    }

    pub fn acceptMatchesEmbargo(self: *const State, id: QuestionId, embargo: []const u8) ?bool {
        const tracker = self.accepts.get(id) orelse return null;
        return tracker.matchesEmbargo(embargo);
    }

    pub fn acceptCount(self: *const State) usize {
        return self.accepts.count();
    }

    pub fn acceptEmbargoReleased(self: *const State, id: QuestionId) ?bool {
        const tracker = self.accepts.get(id) orelse return null;
        return tracker.embargo_released;
    }

    pub fn acceptReady(self: *const State, id: QuestionId) ?bool {
        const tracker = self.accepts.get(id) orelse return null;
        return tracker.embargo == null or tracker.embargo_released;
    }

    pub fn acceptPendingEmbargo(self: *const State, id: QuestionId) ?[]const u8 {
        const tracker = self.accepts.get(id) orelse return null;
        if (tracker.embargo_released) return null;
        return tracker.embargo;
    }

    pub fn pendingAcceptEmbargoCount(self: *const State) usize {
        var count: usize = 0;
        var iterator = self.accepts.valueIterator();
        while (iterator.next()) |accept| {
            if (accept.embargo != null and !accept.embargo_released) count += 1;
        }
        return count;
    }

    pub fn pendingAcceptEmbargoMatchCount(self: *const State, embargo: []const u8) usize {
        var count: usize = 0;
        var iterator = self.accepts.valueIterator();
        while (iterator.next()) |accept| {
            if (accept.embargo) |tracked| {
                if (!accept.embargo_released and std.mem.eql(u8, tracked, embargo)) count += 1;
            }
        }
        return count;
    }

    pub fn pendingAcceptEmbargoIdsAlloc(self: *const State, allocator: std.mem.Allocator) std.mem.Allocator.Error![]QuestionId {
        var ids = std.ArrayList(QuestionId).empty;
        errdefer ids.deinit(allocator);
        var iterator = self.accepts.iterator();
        while (iterator.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.embargo != null and !accept.embargo_released) try ids.append(allocator, entry.key_ptr.*);
        }
        return ids.toOwnedSlice(allocator);
    }

    pub fn pendingAcceptEmbargoMatchingIdsAlloc(self: *const State, allocator: std.mem.Allocator, embargo: []const u8) std.mem.Allocator.Error![]QuestionId {
        var ids = std.ArrayList(QuestionId).empty;
        errdefer ids.deinit(allocator);
        var iterator = self.accepts.iterator();
        while (iterator.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.embargo) |tracked| {
                if (!accept.embargo_released and std.mem.eql(u8, tracked, embargo)) {
                    try ids.append(allocator, entry.key_ptr.*);
                }
            }
        }
        return ids.toOwnedSlice(allocator);
    }

    pub fn pendingAcceptEmbargosAlloc(self: *const State, allocator: std.mem.Allocator) std.mem.Allocator.Error!PendingAcceptEmbargos {
        var items = std.ArrayList(PendingAcceptEmbargo).empty;
        errdefer {
            for (items.items) |item| allocator.free(item.embargo);
            items.deinit(allocator);
        }
        var iterator = self.accepts.iterator();
        while (iterator.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.embargo) |embargo| {
                if (!accept.embargo_released) {
                    const owned_embargo = try allocator.dupe(u8, embargo);
                    items.append(allocator, .{ .question_id = entry.key_ptr.*, .embargo = owned_embargo }) catch |err| {
                        allocator.free(owned_embargo);
                        return err;
                    };
                }
            }
        }
        return .{ .items = try items.toOwnedSlice(allocator) };
    }

    pub fn pendingAcceptEmbargosMatchingAlloc(self: *const State, allocator: std.mem.Allocator, match_embargo: []const u8) std.mem.Allocator.Error!PendingAcceptEmbargos {
        var items = std.ArrayList(PendingAcceptEmbargo).empty;
        errdefer {
            for (items.items) |item| allocator.free(item.embargo);
            items.deinit(allocator);
        }
        var iterator = self.accepts.iterator();
        while (iterator.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.embargo) |embargo| {
                if (!accept.embargo_released and std.mem.eql(u8, embargo, match_embargo)) {
                    const owned_embargo = try allocator.dupe(u8, embargo);
                    items.append(allocator, .{ .question_id = entry.key_ptr.*, .embargo = owned_embargo }) catch |err| {
                        allocator.free(owned_embargo);
                        return err;
                    };
                }
            }
        }
        return .{ .items = try items.toOwnedSlice(allocator) };
    }

    pub fn initPendingAcceptDisembargoMessages(self: *const State, message_builders: anytype, target: CallTarget) !usize {
        const needed = self.pendingAcceptEmbargoCount();
        if (message_builders.len < needed) return error.InvalidTransition;
        try self.validateCallTarget(target);
        var index: usize = 0;
        var iterator = self.accepts.valueIterator();
        while (iterator.next()) |accept| {
            if (accept.embargo) |embargo| {
                if (!accept.embargo_released) {
                    try initWireDisembargoMessage(message_builders[index], .{
                        .target = target,
                        .context = .{ .accept = embargo },
                    });
                    index += 1;
                }
            }
        }
        return index;
    }

    pub fn initPendingAcceptDisembargoMessagesToSink(
        self: *const State,
        message_builders: anytype,
        target: CallTarget,
        sink_context: anytype,
        sink_handler: anytype,
    ) !usize {
        const needed = self.pendingAcceptEmbargoCount();
        if (message_builders.len < needed) return error.InvalidTransition;
        try self.validateCallTarget(target);
        var index: usize = 0;
        var iterator = self.accepts.valueIterator();
        while (iterator.next()) |accept| {
            if (accept.embargo) |embargo| {
                if (!accept.embargo_released) {
                    try initWireDisembargoMessage(message_builders[index], .{
                        .target = target,
                        .context = .{ .accept = embargo },
                    });
                    try sink_handler(sink_context, message_builders[index]);
                    index += 1;
                }
            }
        }
        return index;
    }

    pub fn initPendingAcceptDisembargoMessagesToQueue(self: *const State, allocator: std.mem.Allocator, message_builders: anytype, target: CallTarget, queue: anytype) !usize {
        const initialized = try self.initPendingAcceptDisembargoMessages(message_builders, target);
        for (message_builders[0..initialized]) |message| {
            try queue.append(allocator, message);
        }
        return initialized;
    }

    pub fn initPendingAcceptDisembargoMessagesForEmbargo(self: *const State, message_builders: anytype, target: CallTarget, embargo: []const u8) !usize {
        const needed = self.pendingAcceptEmbargoMatchCount(embargo);
        if (message_builders.len < needed) return error.InvalidTransition;
        try self.validateCallTarget(target);
        var index: usize = 0;
        var iterator = self.accepts.valueIterator();
        while (iterator.next()) |accept| {
            if (accept.embargo) |tracked| {
                if (!accept.embargo_released and std.mem.eql(u8, tracked, embargo)) {
                    try initWireDisembargoMessage(message_builders[index], .{
                        .target = target,
                        .context = .{ .accept = tracked },
                    });
                    index += 1;
                }
            }
        }
        return index;
    }

    pub fn initPendingAcceptDisembargoMessagesForEmbargoToSink(
        self: *const State,
        message_builders: anytype,
        target: CallTarget,
        embargo: []const u8,
        sink_context: anytype,
        sink_handler: anytype,
    ) !usize {
        const needed = self.pendingAcceptEmbargoMatchCount(embargo);
        if (message_builders.len < needed) return error.InvalidTransition;
        try self.validateCallTarget(target);
        var index: usize = 0;
        var iterator = self.accepts.valueIterator();
        while (iterator.next()) |accept| {
            if (accept.embargo) |tracked| {
                if (!accept.embargo_released and std.mem.eql(u8, tracked, embargo)) {
                    try initWireDisembargoMessage(message_builders[index], .{
                        .target = target,
                        .context = .{ .accept = tracked },
                    });
                    try sink_handler(sink_context, message_builders[index]);
                    index += 1;
                }
            }
        }
        return index;
    }

    pub fn initPendingAcceptDisembargoMessagesForEmbargoToQueue(self: *const State, allocator: std.mem.Allocator, message_builders: anytype, target: CallTarget, embargo: []const u8, queue: anytype) !usize {
        const initialized = try self.initPendingAcceptDisembargoMessagesForEmbargo(message_builders, target, embargo);
        for (message_builders[0..initialized]) |message| {
            try queue.append(allocator, message);
        }
        return initialized;
    }

    pub fn readyAcceptProvision(self: *const State, id: QuestionId) ?AnyPointerUsage {
        const tracker = self.accepts.get(id) orelse return null;
        if (tracker.embargo != null and !tracker.embargo_released) return null;
        return tracker.provision;
    }

    pub fn readyAcceptProvisionCount(self: *const State) usize {
        var count: usize = 0;
        var iterator = self.accepts.valueIterator();
        while (iterator.next()) |accept| {
            if (accept.provision != null and (accept.embargo == null or accept.embargo_released)) {
                count += 1;
            }
        }
        return count;
    }

    pub fn initReadyAcceptReturnMessage(self: *const State, message: anytype, question_id: QuestionId, export_id: ExportId) !void {
        _ = self.readyAcceptProvision(question_id) orelse return error.InvalidTransition;
        try initCapabilityReturnMessage(message, question_id, export_id);
    }

    pub fn initReadyAcceptReturnMessageFromHandler(
        self: *const State,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
    ) !void {
        const provision = self.readyAcceptProvision(question_id) orelse return error.InvalidTransition;
        const export_id = try handler(context, question_id, provision);
        try self.initReadyAcceptReturnMessage(message, question_id, export_id);
    }

    pub fn initReadyAcceptReturnMessageFromHandlerToSink(
        self: *const State,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !void {
        try self.initReadyAcceptReturnMessageFromHandler(message, question_id, context, handler);
        try sink_handler(sink_context, message);
    }

    pub fn initReadyAcceptReturnMessageFromHandlerToQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
        queue: anytype,
    ) !void {
        try self.initReadyAcceptReturnMessageFromHandler(message, question_id, context, handler);
        try queue.append(allocator, message);
    }

    pub fn initReleasedAcceptReturnMessages(
        self: *const State,
        response_messages: anytype,
        released_accept_ids: []const QuestionId,
        export_ids: []const ExportId,
    ) !usize {
        if (response_messages.len < released_accept_ids.len or export_ids.len < released_accept_ids.len) return error.InvalidTransition;
        for (released_accept_ids, 0..) |question_id, index| {
            try self.initReadyAcceptReturnMessage(response_messages[index], question_id, export_ids[index]);
        }
        return released_accept_ids.len;
    }

    pub fn initReleasedAcceptReturnMessagesToSink(
        self: *const State,
        response_messages: anytype,
        released_accept_ids: []const QuestionId,
        export_ids: []const ExportId,
        sink_context: anytype,
        sink_handler: anytype,
    ) !usize {
        if (response_messages.len < released_accept_ids.len or export_ids.len < released_accept_ids.len) return error.InvalidTransition;
        for (released_accept_ids, 0..) |question_id, index| {
            try self.initReadyAcceptReturnMessage(response_messages[index], question_id, export_ids[index]);
            try sink_handler(sink_context, response_messages[index]);
        }
        return released_accept_ids.len;
    }

    pub fn initReleasedAcceptReturnMessagesToQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        released_accept_ids: []const QuestionId,
        export_ids: []const ExportId,
        queue: anytype,
    ) !usize {
        if (response_messages.len < released_accept_ids.len or export_ids.len < released_accept_ids.len) return error.InvalidTransition;
        for (released_accept_ids, 0..) |question_id, index| {
            try self.initReadyAcceptReturnMessage(response_messages[index], question_id, export_ids[index]);
            try queue.append(allocator, response_messages[index]);
        }
        return released_accept_ids.len;
    }

    pub fn initReleasedAcceptReturnMessagesFromHandler(
        self: *const State,
        response_messages: anytype,
        released_accept_ids: []const QuestionId,
        context: anytype,
        handler: anytype,
    ) !usize {
        if (response_messages.len < released_accept_ids.len) return error.InvalidTransition;
        for (released_accept_ids, 0..) |question_id, index| {
            const provision = self.readyAcceptProvision(question_id) orelse return error.InvalidTransition;
            const export_id = try handler(context, question_id, provision);
            try self.initReadyAcceptReturnMessage(response_messages[index], question_id, export_id);
        }
        return released_accept_ids.len;
    }

    pub fn initReleasedAcceptReturnMessagesFromHandlerToSink(
        self: *const State,
        response_messages: anytype,
        released_accept_ids: []const QuestionId,
        context: anytype,
        handler: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !usize {
        if (response_messages.len < released_accept_ids.len) return error.InvalidTransition;
        for (released_accept_ids, 0..) |question_id, index| {
            const provision = self.readyAcceptProvision(question_id) orelse return error.InvalidTransition;
            const export_id = try handler(context, question_id, provision);
            try self.initReadyAcceptReturnMessage(response_messages[index], question_id, export_id);
            try sink_handler(sink_context, response_messages[index]);
        }
        return released_accept_ids.len;
    }

    pub fn initReleasedAcceptReturnMessagesFromHandlerToQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        released_accept_ids: []const QuestionId,
        context: anytype,
        handler: anytype,
        queue: anytype,
    ) !usize {
        if (response_messages.len < released_accept_ids.len) return error.InvalidTransition;
        for (released_accept_ids, 0..) |question_id, index| {
            const provision = self.readyAcceptProvision(question_id) orelse return error.InvalidTransition;
            const export_id = try handler(context, question_id, provision);
            try self.initReadyAcceptReturnMessage(response_messages[index], question_id, export_id);
            try queue.append(allocator, response_messages[index]);
        }
        return released_accept_ids.len;
    }

    pub fn applyDisembargoAndInitAcceptReturnsFromHandlerToSink(
        self: *State,
        allocator: std.mem.Allocator,
        info: DisembargoInfo,
        response_messages: anytype,
        context: anytype,
        handler: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !DisembargoApplyInfo {
        const expected_accepts = switch (info.context) {
            .accept => |embargo| self.pendingAcceptEmbargoMatchCount(embargo),
            else => 0,
        };
        if (response_messages.len < expected_accepts) return error.InvalidTransition;
        const released = try self.applyDisembargoAlloc(allocator, info);
        errdefer allocator.free(released.released_accept_ids);
        _ = try self.initReleasedAcceptReturnMessagesFromHandlerToSink(
            response_messages,
            released.released_accept_ids,
            context,
            handler,
            sink_context,
            sink_handler,
        );
        return released;
    }

    pub fn applyDisembargoAndInitAcceptReturnsFromHandlerToQueue(
        self: *State,
        allocator: std.mem.Allocator,
        info: DisembargoInfo,
        response_messages: anytype,
        context: anytype,
        handler: anytype,
        queue: anytype,
    ) !DisembargoApplyInfo {
        const expected_accepts = switch (info.context) {
            .accept => |embargo| self.pendingAcceptEmbargoMatchCount(embargo),
            else => 0,
        };
        if (response_messages.len < expected_accepts) return error.InvalidTransition;
        const released = try self.applyDisembargoAlloc(allocator, info);
        errdefer allocator.free(released.released_accept_ids);
        _ = try self.initReleasedAcceptReturnMessagesFromHandlerToQueue(
            allocator,
            response_messages,
            released.released_accept_ids,
            context,
            handler,
            queue,
        );
        return released;
    }

    pub fn applyDisembargoAndInitAcceptReturnsFromHandler(
        self: *State,
        allocator: std.mem.Allocator,
        info: DisembargoInfo,
        response_messages: anytype,
        context: anytype,
        handler: anytype,
    ) !DisembargoApplyInfo {
        const expected_accepts = switch (info.context) {
            .accept => |embargo| self.pendingAcceptEmbargoMatchCount(embargo),
            else => 0,
        };
        if (response_messages.len < expected_accepts) return error.InvalidTransition;
        const released = try self.applyDisembargoAlloc(allocator, info);
        errdefer allocator.free(released.released_accept_ids);
        _ = try self.initReleasedAcceptReturnMessagesFromHandler(
            response_messages,
            released.released_accept_ids,
            context,
            handler,
        );
        return released;
    }

    pub fn applyWireDisembargoAndInitAcceptReturnsFromHandler(
        self: *State,
        allocator: std.mem.Allocator,
        disembargo: anytype,
        response_messages: anytype,
        context: anytype,
        handler: anytype,
    ) !DisembargoApplyInfo {
        return self.applyDisembargoAndInitAcceptReturnsFromHandler(
            allocator,
            try disembargoInfoFromWireDisembargo(disembargo),
            response_messages,
            context,
            handler,
        );
    }

    pub fn applyWireDisembargoAndInitAcceptReturnsFromHandlerToQueue(
        self: *State,
        allocator: std.mem.Allocator,
        disembargo: anytype,
        response_messages: anytype,
        context: anytype,
        handler: anytype,
        queue: anytype,
    ) !DisembargoApplyInfo {
        return self.applyDisembargoAndInitAcceptReturnsFromHandlerToQueue(
            allocator,
            try disembargoInfoFromWireDisembargo(disembargo),
            response_messages,
            context,
            handler,
            queue,
        );
    }

    pub fn applyWireDisembargoAndInitAcceptReturnsFromHandlerToSink(
        self: *State,
        allocator: std.mem.Allocator,
        disembargo: anytype,
        response_messages: anytype,
        context: anytype,
        handler: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !DisembargoApplyInfo {
        return self.applyDisembargoAndInitAcceptReturnsFromHandlerToSink(
            allocator,
            try disembargoInfoFromWireDisembargo(disembargo),
            response_messages,
            context,
            handler,
            sink_context,
            sink_handler,
        );
    }

    pub fn applyDisembargoAndInitAcceptReturnsToSink(
        self: *State,
        allocator: std.mem.Allocator,
        info: DisembargoInfo,
        response_messages: anytype,
        export_ids: []const ExportId,
        sink_context: anytype,
        sink_handler: anytype,
    ) !DisembargoApplyInfo {
        const expected_accepts = switch (info.context) {
            .accept => |embargo| self.pendingAcceptEmbargoMatchCount(embargo),
            else => 0,
        };
        if (response_messages.len < expected_accepts or export_ids.len < expected_accepts) return error.InvalidTransition;
        const released = try self.applyDisembargoAlloc(allocator, info);
        errdefer allocator.free(released.released_accept_ids);
        _ = try self.initReleasedAcceptReturnMessagesToSink(
            response_messages,
            released.released_accept_ids,
            export_ids,
            sink_context,
            sink_handler,
        );
        return released;
    }

    pub fn applyDisembargoAndInitAcceptReturnsToQueue(
        self: *State,
        allocator: std.mem.Allocator,
        info: DisembargoInfo,
        response_messages: anytype,
        export_ids: []const ExportId,
        queue: anytype,
    ) !DisembargoApplyInfo {
        const expected_accepts = switch (info.context) {
            .accept => |embargo| self.pendingAcceptEmbargoMatchCount(embargo),
            else => 0,
        };
        if (response_messages.len < expected_accepts or export_ids.len < expected_accepts) return error.InvalidTransition;
        const released = try self.applyDisembargoAlloc(allocator, info);
        errdefer allocator.free(released.released_accept_ids);
        _ = try self.initReleasedAcceptReturnMessagesToQueue(
            allocator,
            response_messages,
            released.released_accept_ids,
            export_ids,
            queue,
        );
        return released;
    }

    pub fn applyDisembargoAndInitAcceptReturns(
        self: *State,
        allocator: std.mem.Allocator,
        info: DisembargoInfo,
        response_messages: anytype,
        export_ids: []const ExportId,
    ) !DisembargoApplyInfo {
        const expected_accepts = switch (info.context) {
            .accept => |embargo| self.pendingAcceptEmbargoMatchCount(embargo),
            else => 0,
        };
        if (response_messages.len < expected_accepts or export_ids.len < expected_accepts) return error.InvalidTransition;
        const released = try self.applyDisembargoAlloc(allocator, info);
        errdefer allocator.free(released.released_accept_ids);
        _ = try self.initReleasedAcceptReturnMessages(
            response_messages,
            released.released_accept_ids,
            export_ids,
        );
        return released;
    }

    pub fn applyWireDisembargoAndInitAcceptReturns(
        self: *State,
        allocator: std.mem.Allocator,
        disembargo: anytype,
        response_messages: anytype,
        export_ids: []const ExportId,
    ) !DisembargoApplyInfo {
        return self.applyDisembargoAndInitAcceptReturns(
            allocator,
            try disembargoInfoFromWireDisembargo(disembargo),
            response_messages,
            export_ids,
        );
    }

    pub fn applyWireDisembargoAndInitAcceptReturnsToQueue(
        self: *State,
        allocator: std.mem.Allocator,
        disembargo: anytype,
        response_messages: anytype,
        export_ids: []const ExportId,
        queue: anytype,
    ) !DisembargoApplyInfo {
        return self.applyDisembargoAndInitAcceptReturnsToQueue(
            allocator,
            try disembargoInfoFromWireDisembargo(disembargo),
            response_messages,
            export_ids,
            queue,
        );
    }

    pub fn applyWireDisembargoAndInitAcceptReturnsToSink(
        self: *State,
        allocator: std.mem.Allocator,
        disembargo: anytype,
        response_messages: anytype,
        export_ids: []const ExportId,
        sink_context: anytype,
        sink_handler: anytype,
    ) !DisembargoApplyInfo {
        return self.applyDisembargoAndInitAcceptReturnsToSink(
            allocator,
            try disembargoInfoFromWireDisembargo(disembargo),
            response_messages,
            export_ids,
            sink_context,
            sink_handler,
        );
    }

    pub fn joinInfo(self: *const State, id: QuestionId) ?JoinInfo {
        const tracker = self.joins.get(id) orelse return null;
        return tracker.info();
    }

    pub fn joinHasKeyPartUsage(self: *const State, id: QuestionId) ?bool {
        const tracker = self.joins.get(id) orelse return null;
        return tracker.hasKeyPartUsage();
    }

    pub fn joinKeyPartMatchesCapability(self: *const State, id: QuestionId, capability_index: u32) ?bool {
        const tracker = self.joins.get(id) orelse return null;
        return tracker.keyPartMatchesCapability(capability_index);
    }

    pub fn joinTargetsImport(self: *const State, id: QuestionId, import_id: ImportId) ?bool {
        const tracker = self.joins.get(id) orelse return null;
        return tracker.targetsImport(import_id);
    }

    pub fn joinTargetsPromisedQuestion(self: *const State, id: QuestionId, promised_question_id: QuestionId) ?bool {
        const tracker = self.joins.get(id) orelse return null;
        return tracker.targetsPromisedQuestion(promised_question_id);
    }

    pub fn joinKeyPart(self: *const State, id: QuestionId) ?AnyPointerUsage {
        const tracker = self.joins.get(id) orelse return null;
        return tracker.key_part;
    }

    pub fn joinKeyPartCount(self: *const State) usize {
        var count: usize = 0;
        var iterator = self.joins.valueIterator();
        while (iterator.next()) |join| {
            if (join.key_part != null) count += 1;
        }
        return count;
    }

    pub fn joinCount(self: *const State) usize {
        return self.joins.count();
    }

    pub fn initTrackedJoinResultReturnMessage(self: *const State, message: anytype, question_id: QuestionId, export_id: ExportId) !void {
        _ = self.joinKeyPart(question_id) orelse return error.InvalidTransition;
        try initWireJoinResultReturnMessage(message, question_id, true, 0, &.{.{ .sender_hosted = export_id }});
    }

    pub fn initTrackedJoinResultReturnMessageFromHandler(
        self: *const State,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
    ) !void {
        const key_part = self.joinKeyPart(question_id) orelse return error.InvalidTransition;
        const export_id = try handler(context, question_id, key_part);
        try self.initTrackedJoinResultReturnMessage(message, question_id, export_id);
    }

    pub fn initTrackedJoinResultReturnMessageFromHandlerToSink(
        self: *const State,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !void {
        try self.initTrackedJoinResultReturnMessageFromHandler(message, question_id, context, handler);
        try sink_handler(sink_context, message);
    }

    pub fn initTrackedJoinResultReturnMessageFromHandlerToQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
        queue: anytype,
    ) !void {
        try self.initTrackedJoinResultReturnMessageFromHandler(message, question_id, context, handler);
        try queue.append(allocator, message);
    }

    pub fn provideInfo(self: *const State, id: QuestionId) ?ProvideInfo {
        const tracker = self.provides.get(id) orelse return null;
        return tracker.info();
    }

    pub fn provideHasRecipientUsage(self: *const State, id: QuestionId) ?bool {
        const tracker = self.provides.get(id) orelse return null;
        return tracker.hasRecipientUsage();
    }

    pub fn provideRecipientMatchesCapability(self: *const State, id: QuestionId, capability_index: u32) ?bool {
        const tracker = self.provides.get(id) orelse return null;
        return tracker.recipientMatchesCapability(capability_index);
    }

    pub fn provideTargetsImport(self: *const State, id: QuestionId, import_id: ImportId) ?bool {
        const tracker = self.provides.get(id) orelse return null;
        return tracker.targetsImport(import_id);
    }

    pub fn provideTargetsPromisedQuestion(self: *const State, id: QuestionId, promised_question_id: QuestionId) ?bool {
        const tracker = self.provides.get(id) orelse return null;
        return tracker.targetsPromisedQuestion(promised_question_id);
    }

    pub fn provideRecipient(self: *const State, id: QuestionId) ?AnyPointerUsage {
        const tracker = self.provides.get(id) orelse return null;
        return tracker.recipient;
    }

    pub fn provideRecipientCount(self: *const State) usize {
        var count: usize = 0;
        var iterator = self.provides.valueIterator();
        while (iterator.next()) |provide| {
            if (provide.recipient != null) count += 1;
        }
        return count;
    }

    pub fn provideCount(self: *const State) usize {
        return self.provides.count();
    }

    pub fn initTrackedProvideReturnMessage(self: *const State, message: anytype, question_id: QuestionId, export_id: ExportId) !void {
        _ = self.provideRecipient(question_id) orelse return error.InvalidTransition;
        try initCapabilityReturnMessage(message, question_id, export_id);
    }

    pub fn initTrackedProvideReturnMessageFromHandler(
        self: *const State,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
    ) !void {
        const recipient = self.provideRecipient(question_id) orelse return error.InvalidTransition;
        const export_id = try handler(context, question_id, recipient);
        try self.initTrackedProvideReturnMessage(message, question_id, export_id);
    }

    pub fn initTrackedProvideReturnMessageFromHandlerToSink(
        self: *const State,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !void {
        try self.initTrackedProvideReturnMessageFromHandler(message, question_id, context, handler);
        try sink_handler(sink_context, message);
    }

    pub fn initTrackedProvideReturnMessageFromHandlerToQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        message: anytype,
        question_id: QuestionId,
        context: anytype,
        handler: anytype,
        queue: anytype,
    ) !void {
        try self.initTrackedProvideReturnMessageFromHandler(message, question_id, context, handler);
        try queue.append(allocator, message);
    }

    pub fn readyProvideIdsAlloc(self: *const State, allocator: std.mem.Allocator) std.mem.Allocator.Error![]QuestionId {
        var ids = std.ArrayList(QuestionId).empty;
        errdefer ids.deinit(allocator);
        var iterator = self.provides.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.recipient != null) try ids.append(allocator, entry.key_ptr.*);
        }
        return ids.toOwnedSlice(allocator);
    }

    pub fn readyAcceptIdsAlloc(self: *const State, allocator: std.mem.Allocator) std.mem.Allocator.Error![]QuestionId {
        var ids = std.ArrayList(QuestionId).empty;
        errdefer ids.deinit(allocator);
        var iterator = self.accepts.iterator();
        while (iterator.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.provision != null and (accept.embargo == null or accept.embargo_released)) {
                try ids.append(allocator, entry.key_ptr.*);
            }
        }
        return ids.toOwnedSlice(allocator);
    }

    pub fn readyJoinIdsAlloc(self: *const State, allocator: std.mem.Allocator) std.mem.Allocator.Error![]QuestionId {
        var ids = std.ArrayList(QuestionId).empty;
        errdefer ids.deinit(allocator);
        var iterator = self.joins.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.key_part != null) try ids.append(allocator, entry.key_ptr.*);
        }
        return ids.toOwnedSlice(allocator);
    }

    pub fn readyHandoffIdsAlloc(self: *const State, allocator: std.mem.Allocator) std.mem.Allocator.Error!StateReadyHandoffIds {
        const provides = try self.readyProvideIdsAlloc(allocator);
        errdefer allocator.free(provides);
        const accepts = try self.readyAcceptIdsAlloc(allocator);
        errdefer allocator.free(accepts);
        const joins = try self.readyJoinIdsAlloc(allocator);
        errdefer allocator.free(joins);
        return .{ .provides = provides, .accepts = accepts, .joins = joins };
    }

    pub fn validateReadyHandoffReturnPlan(self: *const State, plan: HandoffReturnPlan) Error!void {
        for (plan.provides) |value| {
            _ = self.provideRecipient(value.question_id) orelse return error.InvalidTransition;
        }
        for (plan.accepts) |value| {
            _ = self.readyAcceptProvision(value.question_id) orelse return error.InvalidTransition;
        }
        for (plan.joins) |value| {
            _ = self.joinKeyPart(value.question_id) orelse return error.InvalidTransition;
        }
    }

    pub fn readyHandoffReturnsAlloc(self: *const State, allocator: std.mem.Allocator, plan: HandoffReturnPlan) (Error || std.mem.Allocator.Error)![]HandoffReturn {
        try self.validateReadyHandoffReturnPlan(plan);
        var completions = try allocator.alloc(HandoffReturn, plan.total());
        errdefer allocator.free(completions);
        var index: usize = 0;
        for (plan.provides) |value| {
            completions[index] = .{ .provide = value };
            index += 1;
        }
        for (plan.accepts) |value| {
            completions[index] = .{ .accept = value };
            index += 1;
        }
        for (plan.joins) |value| {
            completions[index] = .{ .join = value };
            index += 1;
        }
        return completions;
    }

    pub fn initTrackedHandoffReturnMessage(self: *const State, message: anytype, completion: HandoffReturn) !void {
        switch (completion) {
            .provide => |value| try self.initTrackedProvideReturnMessage(message, value.question_id, value.export_id),
            .accept => |value| try self.initReadyAcceptReturnMessage(message, value.question_id, value.export_id),
            .join => |value| try self.initTrackedJoinResultReturnMessage(message, value.question_id, value.export_id),
        }
    }

    pub fn validateTrackedHandoffReturn(self: *const State, completion: HandoffReturn) Error!void {
        switch (completion) {
            .provide => |value| _ = self.provideRecipient(value.question_id) orelse return error.InvalidTransition,
            .accept => |value| _ = self.readyAcceptProvision(value.question_id) orelse return error.InvalidTransition,
            .join => |value| _ = self.joinKeyPart(value.question_id) orelse return error.InvalidTransition,
        }
    }

    pub fn validateTrackedHandoffReturns(self: *const State, completions: []const HandoffReturn) Error!void {
        for (completions) |completion| {
            try self.validateTrackedHandoffReturn(completion);
        }
    }

    pub fn initTrackedHandoffReturnMessages(self: *const State, response_messages: anytype, completions: []const HandoffReturn) !StateHandoffReturnStats {
        if (response_messages.len < completions.len) return error.InvalidTransition;
        try self.validateTrackedHandoffReturns(completions);
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            stats.record(completion);
        }
        return stats;
    }

    pub fn initReadyHandoffReturnPlanMessages(self: *const State, response_messages: anytype, plan: HandoffReturnPlan) !StateHandoffReturnStats {
        if (response_messages.len < plan.total()) return error.InvalidTransition;
        try self.validateReadyHandoffReturnPlan(plan);
        var stats: StateHandoffReturnStats = .{};
        var index: usize = 0;
        for (plan.provides) |value| {
            try self.initTrackedProvideReturnMessage(response_messages[index], value.question_id, value.export_id);
            stats.provides += 1;
            index += 1;
        }
        for (plan.accepts) |value| {
            try self.initReadyAcceptReturnMessage(response_messages[index], value.question_id, value.export_id);
            stats.accepts += 1;
            index += 1;
        }
        for (plan.joins) |value| {
            try self.initTrackedJoinResultReturnMessage(response_messages[index], value.question_id, value.export_id);
            stats.joins += 1;
            index += 1;
        }
        return stats;
    }

    pub fn initTrackedHandoffReturnMessagesToSink(
        self: *const State,
        response_messages: anytype,
        completions: []const HandoffReturn,
        sink_context: anytype,
        sink_handler: anytype,
    ) !StateHandoffReturnStats {
        if (response_messages.len < completions.len) return error.InvalidTransition;
        try self.validateTrackedHandoffReturns(completions);
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            try sink_handler(sink_context, response_messages[index]);
            stats.record(completion);
        }
        return stats;
    }

    pub fn initTrackedHandoffReturnMessagesToTaggedSink(
        self: *const State,
        response_messages: anytype,
        completions: []const HandoffReturn,
        sink_context: anytype,
        sink_handler: anytype,
    ) !StateHandoffReturnStats {
        if (response_messages.len < completions.len) return error.InvalidTransition;
        try self.validateTrackedHandoffReturns(completions);
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            const position = stats.nextPosition(completion);
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            try sink_handler(sink_context, position, response_messages[index]);
            stats.record(completion);
        }
        return stats;
    }

    pub fn initTrackedHandoffReturnMessagesToQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        completions: []const HandoffReturn,
        queue: anytype,
    ) !StateHandoffReturnStats {
        if (response_messages.len < completions.len) return error.InvalidTransition;
        try self.validateTrackedHandoffReturns(completions);
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            try queue.append(allocator, response_messages[index]);
            stats.record(completion);
        }
        return stats;
    }

    pub fn initTrackedHandoffReturnMessagesToTaggedQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        completions: []const HandoffReturn,
        queue: anytype,
    ) !StateHandoffReturnStats {
        if (response_messages.len < completions.len) return error.InvalidTransition;
        try self.validateTrackedHandoffReturns(completions);
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            const position = stats.nextPosition(completion);
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            try queue.append(allocator, .{ .position = position, .message = response_messages[index] });
            stats.record(completion);
        }
        return stats;
    }

    pub fn initTrackedHandoffReturnMessagesToSinks(
        self: *const State,
        response_messages: anytype,
        completions: []const HandoffReturn,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
    ) !StateHandoffReturnStats {
        if (response_messages.len < completions.len) return error.InvalidTransition;
        try self.validateTrackedHandoffReturns(completions);
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            switch (completion) {
                .provide => try provide_handler(provide_context, response_messages[index]),
                .accept => try accept_handler(accept_context, response_messages[index]),
                .join => try join_handler(join_context, response_messages[index]),
            }
            stats.record(completion);
        }
        return stats;
    }

    pub fn initTrackedHandoffReturnMessagesToQueues(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        completions: []const HandoffReturn,
        provide_queue: anytype,
        accept_queue: anytype,
        join_queue: anytype,
    ) !StateHandoffReturnStats {
        if (response_messages.len < completions.len) return error.InvalidTransition;
        try self.validateTrackedHandoffReturns(completions);
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            switch (completion) {
                .provide => try provide_queue.append(allocator, response_messages[index]),
                .accept => try accept_queue.append(allocator, response_messages[index]),
                .join => try join_queue.append(allocator, response_messages[index]),
            }
            stats.record(completion);
        }
        return stats;
    }

    pub fn initReadyHandoffReturnPlanMessagesToSink(
        self: *const State,
        response_messages: anytype,
        plan: HandoffReturnPlan,
        sink_context: anytype,
        sink_handler: anytype,
    ) !StateHandoffReturnStats {
        if (response_messages.len < plan.total()) return error.InvalidTransition;
        try self.validateReadyHandoffReturnPlan(plan);
        var stats: StateHandoffReturnStats = .{};
        var index: usize = 0;
        for (plan.provides) |value| {
            try self.initTrackedProvideReturnMessage(response_messages[index], value.question_id, value.export_id);
            try sink_handler(sink_context, response_messages[index]);
            stats.provides += 1;
            index += 1;
        }
        for (plan.accepts) |value| {
            try self.initReadyAcceptReturnMessage(response_messages[index], value.question_id, value.export_id);
            try sink_handler(sink_context, response_messages[index]);
            stats.accepts += 1;
            index += 1;
        }
        for (plan.joins) |value| {
            try self.initTrackedJoinResultReturnMessage(response_messages[index], value.question_id, value.export_id);
            try sink_handler(sink_context, response_messages[index]);
            stats.joins += 1;
            index += 1;
        }
        return stats;
    }

    pub fn initReadyHandoffReturnPlanMessagesToSinks(
        self: *const State,
        response_messages: anytype,
        plan: HandoffReturnPlan,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
    ) !StateHandoffReturnStats {
        const stats = try self.initReadyHandoffReturnPlanMessages(response_messages, plan);
        return sendHandoffReturnOutputsToSinksStats(
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

    pub fn initReadyHandoffReturnPlanMessagesToTaggedSink(
        self: *const State,
        response_messages: anytype,
        plan: HandoffReturnPlan,
        sink_context: anytype,
        sink_handler: anytype,
    ) !StateHandoffReturnStats {
        const stats = try self.initReadyHandoffReturnPlanMessages(response_messages, plan);
        return sendHandoffReturnOutputsToTaggedSinkStats(stats, response_messages, sink_context, sink_handler);
    }

    pub fn initReadyHandoffReturnPlanMessagesToTaggedQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        plan: HandoffReturnPlan,
        queue: anytype,
    ) !StateHandoffReturnStats {
        const stats = try self.initReadyHandoffReturnPlanMessages(response_messages, plan);
        return appendHandoffReturnOutputsToTaggedQueue(allocator, stats, response_messages, queue);
    }

    pub fn initReadyHandoffReturnPlanMessagesToQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        plan: HandoffReturnPlan,
        queue: anytype,
    ) !StateHandoffReturnStats {
        if (response_messages.len < plan.total()) return error.InvalidTransition;
        try self.validateReadyHandoffReturnPlan(plan);
        var stats: StateHandoffReturnStats = .{};
        var index: usize = 0;
        for (plan.provides) |value| {
            try self.initTrackedProvideReturnMessage(response_messages[index], value.question_id, value.export_id);
            try queue.append(allocator, response_messages[index]);
            stats.provides += 1;
            index += 1;
        }
        for (plan.accepts) |value| {
            try self.initReadyAcceptReturnMessage(response_messages[index], value.question_id, value.export_id);
            try queue.append(allocator, response_messages[index]);
            stats.accepts += 1;
            index += 1;
        }
        for (plan.joins) |value| {
            try self.initTrackedJoinResultReturnMessage(response_messages[index], value.question_id, value.export_id);
            try queue.append(allocator, response_messages[index]);
            stats.joins += 1;
            index += 1;
        }
        return stats;
    }

    pub fn initReadyHandoffReturnPlanMessagesToQueues(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        plan: HandoffReturnPlan,
        provide_queue: anytype,
        accept_queue: anytype,
        join_queue: anytype,
    ) !StateHandoffReturnStats {
        const stats = try self.initReadyHandoffReturnPlanMessages(response_messages, plan);
        return appendHandoffReturnOutputsToQueues(
            allocator,
            stats,
            response_messages,
            provide_queue,
            accept_queue,
            join_queue,
        );
    }

    pub fn readyHandoffReturnStats(self: *const State) StateHandoffReturnStats {
        return .{
            .provides = self.provideRecipientCount(),
            .accepts = self.readyAcceptProvisionCount(),
            .joins = self.joinKeyPartCount(),
        };
    }

    pub fn readyHandoffReturnsFromHandlersAlloc(
        self: *const State,
        allocator: std.mem.Allocator,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
    ) ![]HandoffReturn {
        const needed = self.readyHandoffReturnStats().total();
        var completions = try allocator.alloc(HandoffReturn, needed);
        errdefer allocator.free(completions);

        var index: usize = 0;
        var provides = self.provides.iterator();
        while (provides.next()) |entry| {
            if (entry.value_ptr.recipient) |recipient| {
                completions[index] = .{ .provide = .{
                    .question_id = entry.key_ptr.*,
                    .export_id = try provide_handler(provide_context, entry.key_ptr.*, recipient),
                } };
                index += 1;
            }
        }

        var accepts = self.accepts.iterator();
        while (accepts.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.provision != null and (accept.embargo == null or accept.embargo_released)) {
                completions[index] = .{ .accept = .{
                    .question_id = entry.key_ptr.*,
                    .export_id = try accept_handler(accept_context, entry.key_ptr.*, accept.provision.?),
                } };
                index += 1;
            }
        }

        var joins = self.joins.iterator();
        while (joins.next()) |entry| {
            if (entry.value_ptr.key_part) |key_part| {
                completions[index] = .{ .join = .{
                    .question_id = entry.key_ptr.*,
                    .export_id = try join_handler(join_context, entry.key_ptr.*, key_part),
                } };
                index += 1;
            }
        }

        return completions;
    }

    pub fn initReadyHandoffReturnMessagesFromHandlers(
        self: *const State,
        response_messages: anytype,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
    ) !StateHandoffReturnStats {
        return self.initReadyHandoffReturnMessagesFromHandlersToSink(
            response_messages,
            provide_context,
            provide_handler,
            accept_context,
            accept_handler,
            join_context,
            join_handler,
            {},
            ignoreInitializedMessage,
        );
    }

    pub fn initReadyHandoffReturnMessagesFromHandlersToSink(
        self: *const State,
        response_messages: anytype,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !StateHandoffReturnStats {
        const needed = self.provideRecipientCount() + self.readyAcceptProvisionCount() + self.joinKeyPartCount();
        if (response_messages.len < needed) return error.InvalidTransition;
        var stats: StateHandoffReturnStats = .{};
        var index: usize = 0;
        var provides = self.provides.iterator();
        while (provides.next()) |entry| {
            if (entry.value_ptr.recipient) |recipient| {
                const export_id = try provide_handler(provide_context, entry.key_ptr.*, recipient);
                try self.initTrackedProvideReturnMessage(response_messages[index], entry.key_ptr.*, export_id);
                try sink_handler(sink_context, response_messages[index]);
                stats.provides += 1;
                index += 1;
            }
        }
        var accepts = self.accepts.iterator();
        while (accepts.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.provision != null and (accept.embargo == null or accept.embargo_released)) {
                const export_id = try accept_handler(accept_context, entry.key_ptr.*, accept.provision.?);
                try self.initReadyAcceptReturnMessage(response_messages[index], entry.key_ptr.*, export_id);
                try sink_handler(sink_context, response_messages[index]);
                stats.accepts += 1;
                index += 1;
            }
        }
        var joins = self.joins.iterator();
        while (joins.next()) |entry| {
            if (entry.value_ptr.key_part) |key_part| {
                const export_id = try join_handler(join_context, entry.key_ptr.*, key_part);
                try self.initTrackedJoinResultReturnMessage(response_messages[index], entry.key_ptr.*, export_id);
                try sink_handler(sink_context, response_messages[index]);
                stats.joins += 1;
                index += 1;
            }
        }
        return stats;
    }

    pub fn initReadyHandoffReturnMessagesFromHandlersToTaggedSink(
        self: *const State,
        response_messages: anytype,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !StateHandoffReturnStats {
        const stats = try self.initReadyHandoffReturnMessagesFromHandlers(
            response_messages,
            provide_context,
            provide_handler,
            accept_context,
            accept_handler,
            join_context,
            join_handler,
        );
        return sendHandoffReturnOutputsToTaggedSinkStats(stats, response_messages, sink_context, sink_handler);
    }

    pub fn initReadyHandoffReturnMessagesFromHandlersToTaggedQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
        queue: anytype,
    ) !StateHandoffReturnStats {
        const stats = try self.initReadyHandoffReturnMessagesFromHandlers(
            response_messages,
            provide_context,
            provide_handler,
            accept_context,
            accept_handler,
            join_context,
            join_handler,
        );
        return appendHandoffReturnOutputsToTaggedQueue(allocator, stats, response_messages, queue);
    }

    pub fn initReadyHandoffReturnMessagesFromHandlersToSinks(
        self: *const State,
        response_messages: anytype,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
        provide_sink_context: anytype,
        provide_sink_handler: anytype,
        accept_sink_context: anytype,
        accept_sink_handler: anytype,
        join_sink_context: anytype,
        join_sink_handler: anytype,
    ) !StateHandoffReturnStats {
        const stats = try self.initReadyHandoffReturnMessagesFromHandlers(
            response_messages,
            provide_context,
            provide_handler,
            accept_context,
            accept_handler,
            join_context,
            join_handler,
        );
        return sendHandoffReturnOutputsToSinksStats(
            stats,
            response_messages,
            provide_sink_context,
            provide_sink_handler,
            accept_sink_context,
            accept_sink_handler,
            join_sink_context,
            join_sink_handler,
        );
    }

    pub fn initReadyHandoffReturnMessagesFromHandlersToQueues(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
        provide_queue: anytype,
        accept_queue: anytype,
        join_queue: anytype,
    ) !StateHandoffReturnStats {
        const stats = try self.initReadyHandoffReturnMessagesFromHandlers(
            response_messages,
            provide_context,
            provide_handler,
            accept_context,
            accept_handler,
            join_context,
            join_handler,
        );
        return appendHandoffReturnOutputsToQueues(
            allocator,
            stats,
            response_messages,
            provide_queue,
            accept_queue,
            join_queue,
        );
    }

    pub fn initReadyHandoffReturnMessagesFromHandlersToQueue(
        self: *const State,
        allocator: std.mem.Allocator,
        response_messages: anytype,
        provide_context: anytype,
        provide_handler: anytype,
        accept_context: anytype,
        accept_handler: anytype,
        join_context: anytype,
        join_handler: anytype,
        queue: anytype,
    ) !StateHandoffReturnStats {
        const needed = self.provideRecipientCount() + self.readyAcceptProvisionCount() + self.joinKeyPartCount();
        if (response_messages.len < needed) return error.InvalidTransition;
        var stats: StateHandoffReturnStats = .{};
        var index: usize = 0;
        var provides = self.provides.iterator();
        while (provides.next()) |entry| {
            if (entry.value_ptr.recipient) |recipient| {
                const export_id = try provide_handler(provide_context, entry.key_ptr.*, recipient);
                try self.initTrackedProvideReturnMessage(response_messages[index], entry.key_ptr.*, export_id);
                try queue.append(allocator, response_messages[index]);
                stats.provides += 1;
                index += 1;
            }
        }
        var accepts = self.accepts.iterator();
        while (accepts.next()) |entry| {
            const accept = entry.value_ptr;
            if (accept.provision != null and (accept.embargo == null or accept.embargo_released)) {
                const export_id = try accept_handler(accept_context, entry.key_ptr.*, accept.provision.?);
                try self.initReadyAcceptReturnMessage(response_messages[index], entry.key_ptr.*, export_id);
                try queue.append(allocator, response_messages[index]);
                stats.accepts += 1;
                index += 1;
            }
        }
        var joins = self.joins.iterator();
        while (joins.next()) |entry| {
            if (entry.value_ptr.key_part) |key_part| {
                const export_id = try join_handler(join_context, entry.key_ptr.*, key_part);
                try self.initTrackedJoinResultReturnMessage(response_messages[index], entry.key_ptr.*, export_id);
                try queue.append(allocator, response_messages[index]);
                stats.joins += 1;
                index += 1;
            }
        }
        return stats;
    }

    pub fn handoffStats(self: *const State) StateHandoffStats {
        return .{
            .provides = self.provideCount(),
            .provide_recipients = self.provideRecipientCount(),
            .accepts = self.acceptCount(),
            .pending_accept_embargos = self.pendingAcceptEmbargoCount(),
            .ready_accept_provisions = self.readyAcceptProvisionCount(),
            .joins = self.joinCount(),
            .join_key_parts = self.joinKeyPartCount(),
        };
    }

    pub fn callInfo(self: *const State, id: QuestionId) ?CallInfo {
        return self.calls.get(id);
    }

    pub fn trackedCallTarget(self: *const State, id: QuestionId) ?CallTarget {
        const info = self.callInfo(id) orelse return null;
        return info.target;
    }

    pub fn trackedCallTargetResolution(self: *const State, id: QuestionId) ?CapDescriptor {
        const target = self.trackedCallTarget(id) orelse return null;
        return self.callTargetResolution(target);
    }

    pub fn trackedCallTargetResolved(self: *const State, id: QuestionId) ?bool {
        const target = self.trackedCallTarget(id) orelse return null;
        return self.callTargetResolved(target);
    }

    pub fn trackedCallTargetForwardTarget(self: *const State, id: QuestionId) ?CallTarget {
        const target = self.trackedCallTarget(id) orelse return null;
        return self.callTargetForwardTarget(target);
    }

    pub fn trackedCallTargetTransitiveForwardTarget(self: *const State, id: QuestionId) Error!?CallTarget {
        const target = self.trackedCallTarget(id) orelse return null;
        return try self.callTargetTransitiveForwardTarget(target);
    }

    pub fn trackedCallEffectiveTarget(self: *const State, id: QuestionId) ?CallTarget {
        const target = self.trackedCallTarget(id) orelse return null;
        return self.effectiveCallTarget(target);
    }

    pub fn trackedCallTransitiveEffectiveTarget(self: *const State, id: QuestionId) Error!?CallTarget {
        const target = self.trackedCallTarget(id) orelse return null;
        return try self.transitiveEffectiveCallTarget(target);
    }

    pub fn trackedCallMethodEntryIndex(self: *const State, id: QuestionId, comptime entries: anytype) Error!?usize {
        const info = self.callInfo(id) orelse return null;
        return try info.method.entryIndex(entries);
    }

    pub fn trackedCallServiceAction(self: *const State, id: QuestionId, comptime entries: anytype) Error!?TrackedCallServiceAction {
        const dispatch_info = (try self.trackedCallDispatchInfo(id)) orelse return null;
        return try dispatch_info.serviceAction(entries);
    }

    fn dispatchInfoForCallInfo(self: *const State, info: CallInfo) Error!TrackedCallDispatchInfo {
        return .{
            .info = info,
            .options = info.callOptions(),
            .resolution = self.callTargetResolution(info.target),
            .forward_target = self.callTargetForwardTarget(info.target),
            .effective_target = self.effectiveCallTarget(info.target),
            .transitive_forward_target = try self.callTargetTransitiveForwardTarget(info.target),
            .transitive_effective_target = try self.transitiveEffectiveCallTarget(info.target),
        };
    }

    pub fn wireCallDispatchInfo(self: *const State, call: anytype) !TrackedCallDispatchInfo {
        const info = try callInfoFromWireCall(call);
        try self.validateCallTarget(info.target);
        return try self.dispatchInfoForCallInfo(info);
    }

    pub fn wireCallDispatchOutcome(self: *const State, call: anytype) !WireDispatchOutcome {
        const dispatch_info = try self.wireCallDispatchInfo(call);
        return dispatch_info.dispatchOutcome();
    }

    pub fn wireCallServiceAction(self: *const State, call: anytype, comptime entries: anytype) !TrackedCallServiceAction {
        const dispatch_info = try self.wireCallDispatchInfo(call);
        return try dispatch_info.serviceAction(entries);
    }

    pub fn wireMessageDispatchInfo(self: *const State, message: anytype) !?TrackedCallDispatchInfo {
        return switch (try wireMessageTag(message)) {
            .call => try self.wireCallDispatchInfo(try message.call()),
            else => null,
        };
    }

    pub fn wireMessageDispatchOutcome(self: *const State, message: anytype) !?WireDispatchOutcome {
        const dispatch_info = (try self.wireMessageDispatchInfo(message)) orelse return null;
        return dispatch_info.dispatchOutcome();
    }

    pub fn wireMessageServiceAction(self: *const State, message: anytype, comptime entries: anytype) !?TrackedCallServiceAction {
        const dispatch_info = (try self.wireMessageDispatchInfo(message)) orelse return null;
        return try dispatch_info.serviceAction(entries);
    }

    pub fn wireCallServiceActionStats(self: *const State, calls: anytype, comptime entries: anytype) !TrackedCallServiceActionStats {
        var stats: TrackedCallServiceActionStats = .{};
        for (calls) |call| stats.record(try self.wireCallServiceAction(call, entries));
        return stats;
    }

    pub fn wireMessageServiceActionStats(self: *const State, messages: anytype, comptime entries: anytype) !TrackedCallServiceActionStats {
        var stats: TrackedCallServiceActionStats = .{};
        for (messages) |message| {
            if (try self.wireMessageServiceAction(message, entries)) |action|
                stats.record(action)
            else
                stats.recordSkipped();
        }
        return stats;
    }

    pub fn trackedCallServiceActionStats(self: *const State, ids: []const QuestionId, comptime entries: anytype) !TrackedCallServiceActionStats {
        var stats: TrackedCallServiceActionStats = .{};
        for (ids) |id| {
            if (try self.trackedCallServiceAction(id, entries)) |action| {
                stats.record(action);
            } else {
                stats.recordMissing();
            }
        }
        return stats;
    }

    fn storeServiceActionByRange(stats: TrackedCallServiceActionStats, actions: []TrackedCallServiceAction, indexes: anytype, action: TrackedCallServiceAction) void {
        switch (action) {
            .dispatch => {
                actions[indexes.dispatch] = action;
                indexes.dispatch += 1;
            },
            .forward => {
                actions[indexes.forward] = action;
                indexes.forward += 1;
            },
            .unimplemented => {
                actions[indexes.unimplemented] = action;
                indexes.unimplemented += 1;
            },
        }
        std.debug.assert(indexes.dispatch <= stats.dispatchRange().end);
        std.debug.assert(indexes.forward <= stats.forwardRange().end);
        std.debug.assert(indexes.unimplemented <= stats.unimplementedRange().end);
    }

    fn storeServiceActionPlanByRange(stats: TrackedCallServiceActionStats, plans: []TrackedCallServiceActionPlan, indexes: anytype, plan: TrackedCallServiceActionPlan) void {
        switch (plan.action) {
            .dispatch => {
                plans[indexes.dispatch] = plan;
                indexes.dispatch += 1;
            },
            .forward => {
                plans[indexes.forward] = plan;
                indexes.forward += 1;
            },
            .unimplemented => {
                plans[indexes.unimplemented] = plan;
                indexes.unimplemented += 1;
            },
        }
        std.debug.assert(indexes.dispatch <= stats.dispatchRange().end);
        std.debug.assert(indexes.forward <= stats.forwardRange().end);
        std.debug.assert(indexes.unimplemented <= stats.unimplementedRange().end);
    }

    pub fn initWireCallServiceActions(self: *const State, calls: anytype, comptime entries: anytype, actions: []TrackedCallServiceAction) !TrackedCallServiceActionStats {
        const stats = try self.wireCallServiceActionStats(calls, entries);
        try stats.validateActionCapacity(actions.len);
        var indexes = .{
            .dispatch = stats.dispatchRange().start,
            .forward = stats.forwardRange().start,
            .unimplemented = stats.unimplementedRange().start,
        };
        for (calls) |call| storeServiceActionByRange(stats, actions, &indexes, try self.wireCallServiceAction(call, entries));
        return stats;
    }

    pub fn initWireMessageServiceActions(self: *const State, messages: anytype, comptime entries: anytype, actions: []TrackedCallServiceAction) !TrackedCallServiceActionStats {
        const stats = try self.wireMessageServiceActionStats(messages, entries);
        try stats.validateActionCapacity(actions.len);
        var indexes = .{
            .dispatch = stats.dispatchRange().start,
            .forward = stats.forwardRange().start,
            .unimplemented = stats.unimplementedRange().start,
        };
        for (messages) |message| {
            if (try self.wireMessageServiceAction(message, entries)) |action| {
                storeServiceActionByRange(stats, actions, &indexes, action);
            }
        }
        return stats;
    }

    pub fn initTrackedCallServiceActions(self: *const State, ids: []const QuestionId, comptime entries: anytype, actions: []TrackedCallServiceAction) !TrackedCallServiceActionStats {
        const stats = try self.trackedCallServiceActionStats(ids, entries);
        try stats.validateActionCapacity(actions.len);
        var indexes = .{
            .dispatch = stats.dispatchRange().start,
            .forward = stats.forwardRange().start,
            .unimplemented = stats.unimplementedRange().start,
        };
        for (ids) |id| {
            if (try self.trackedCallServiceAction(id, entries)) |action| storeServiceActionByRange(stats, actions, &indexes, action);
        }
        return stats;
    }

    pub fn initWireCallServiceActionPlans(self: *const State, calls: anytype, comptime entries: anytype, plans: []TrackedCallServiceActionPlan) !TrackedCallServiceActionStats {
        const stats = try self.wireCallServiceActionStats(calls, entries);
        try stats.validateActionCapacity(plans.len);
        var indexes = .{
            .dispatch = stats.dispatchRange().start,
            .forward = stats.forwardRange().start,
            .unimplemented = stats.unimplementedRange().start,
        };
        for (calls, 0..) |call, source_index| {
            const action = try self.wireCallServiceAction(call, entries);
            storeServiceActionPlanByRange(stats, plans, &indexes, .{
                .source_index = source_index,
                .question_id = call.questionId(),
                .action = action,
            });
        }
        return stats;
    }

    pub fn initWireMessageServiceActionPlans(self: *const State, messages: anytype, comptime entries: anytype, plans: []TrackedCallServiceActionPlan) !TrackedCallServiceActionStats {
        const stats = try self.wireMessageServiceActionStats(messages, entries);
        try stats.validateActionCapacity(plans.len);
        var indexes = .{
            .dispatch = stats.dispatchRange().start,
            .forward = stats.forwardRange().start,
            .unimplemented = stats.unimplementedRange().start,
        };
        for (messages, 0..) |message, source_index| {
            if (try self.wireMessageDispatchInfo(message)) |dispatch_info| {
                storeServiceActionPlanByRange(stats, plans, &indexes, .{
                    .source_index = source_index,
                    .question_id = dispatch_info.info.question_id,
                    .action = try dispatch_info.serviceAction(entries),
                });
            }
        }
        return stats;
    }

    pub fn dispatchWireCallServiceActions(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        response_messages: anytype,
        forward_messages: anytype,
        context: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.initWireCallServiceActionPlans(calls, entries, plans);
        return initWireCallServiceActionPlanOutputs(self, allocator, calls, plans[0..stats.actions()], response_messages, forward_messages, context, entries);
    }

    pub fn dispatchWireCallServiceActionsToSinks(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        response_messages: anytype,
        forward_messages: anytype,
        context: anytype,
        response_context: anytype,
        response_handler: anytype,
        forward_context: anytype,
        forward_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.initWireCallServiceActionPlans(calls, entries, plans);
        return initWireCallServiceActionPlanOutputsToSinks(
            self,
            allocator,
            calls,
            plans[0..stats.actions()],
            response_messages,
            forward_messages,
            context,
            entries,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
        );
    }

    pub fn dispatchWireMessageServiceActions(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        response_messages: anytype,
        forward_messages: anytype,
        context: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.initWireMessageServiceActionPlans(messages, entries, plans);
        _ = try initWireMessageServiceActionPlanOutputs(self, allocator, messages, plans[0..stats.actions()], response_messages, forward_messages, context, entries);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsToSinks(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        response_messages: anytype,
        forward_messages: anytype,
        context: anytype,
        response_context: anytype,
        response_handler: anytype,
        forward_context: anytype,
        forward_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.initWireMessageServiceActionPlans(messages, entries, plans);
        _ = try initWireMessageServiceActionPlanOutputsToSinks(
            self,
            allocator,
            messages,
            plans[0..stats.actions()],
            response_messages,
            forward_messages,
            context,
            entries,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
        );
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnified(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.initWireCallServiceActionPlans(calls, entries, plans);
        return initWireCallServiceActionPlanUnifiedOutputs(self, allocator, calls, plans[0..stats.actions()], output_messages, context, entries);
    }

    pub fn dispatchWireMessageServiceActionsUnified(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.initWireMessageServiceActionPlans(messages, entries, plans);
        _ = try initWireMessageServiceActionPlanUnifiedOutputs(self, allocator, messages, plans[0..stats.actions()], output_messages, context, entries);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedToSink(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputsToSink(stats, output_messages, sink_context, sink_handler);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedToQueue(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputsToQueue(allocator, stats, output_messages, queue);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedToQueues(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        response_queue: anytype,
        forward_queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputsToQueues(allocator, stats, output_messages, response_queue, forward_queue);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedToSinks(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        response_context: anytype,
        response_handler: anytype,
        forward_context: anytype,
        forward_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputsToSinks(stats, output_messages, response_context, response_handler, forward_context, forward_handler);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedToTaggedSink(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputsToTaggedSink(stats, output_messages, sink_context, sink_handler);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedToTaggedQueue(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputsToTaggedQueue(allocator, stats, output_messages, queue);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedOutputPlansToSink(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputPlansToSink(stats, plans[0..stats.actions()], output_messages, sink_context, sink_handler);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedOutputPlansToQueue(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputPlansToQueue(allocator, stats, plans[0..stats.actions()], output_messages, queue);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedOutputPlansToQueues(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        response_queue: anytype,
        forward_queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputPlansToQueues(allocator, stats, plans[0..stats.actions()], output_messages, response_queue, forward_queue);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedOutputPlansToSinks(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        response_context: anytype,
        response_handler: anytype,
        forward_context: anytype,
        forward_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputPlansToSinks(stats, plans[0..stats.actions()], output_messages, response_context, response_handler, forward_context, forward_handler);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedOutputPlansToTaggedSink(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputPlansToTaggedSink(stats, plans[0..stats.actions()], output_messages, sink_context, sink_handler);
        return stats;
    }

    pub fn dispatchWireMessageServiceActionsUnifiedOutputPlansToTaggedQueue(
        self: *State,
        allocator: std.mem.Allocator,
        messages: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireMessageServiceActionsUnified(allocator, messages, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(allocator, stats, plans[0..stats.actions()], output_messages, queue);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedToSink(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputsToSink(stats, output_messages, sink_context, sink_handler);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedToQueue(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputsToQueue(allocator, stats, output_messages, queue);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedToQueues(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        response_queue: anytype,
        forward_queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputsToQueues(allocator, stats, output_messages, response_queue, forward_queue);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedToSinks(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        response_context: anytype,
        response_handler: anytype,
        forward_context: anytype,
        forward_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputsToSinks(stats, output_messages, response_context, response_handler, forward_context, forward_handler);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedToTaggedSink(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputsToTaggedSink(stats, output_messages, sink_context, sink_handler);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedToTaggedQueue(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputsToTaggedQueue(allocator, stats, output_messages, queue);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedOutputPlansToSink(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputPlansToSink(stats, plans[0..stats.actions()], output_messages, sink_context, sink_handler);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedOutputPlansToQueue(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputPlansToQueue(allocator, stats, plans[0..stats.actions()], output_messages, queue);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedOutputPlansToQueues(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        response_queue: anytype,
        forward_queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputPlansToQueues(allocator, stats, plans[0..stats.actions()], output_messages, response_queue, forward_queue);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedOutputPlansToSinks(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        response_context: anytype,
        response_handler: anytype,
        forward_context: anytype,
        forward_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputPlansToSinks(stats, plans[0..stats.actions()], output_messages, response_context, response_handler, forward_context, forward_handler);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedOutputPlansToTaggedSink(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        sink_context: anytype,
        sink_handler: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        try sendRpcServiceActionUnifiedOutputPlansToTaggedSink(stats, plans[0..stats.actions()], output_messages, sink_context, sink_handler);
        return stats;
    }

    pub fn dispatchWireCallServiceActionsUnifiedOutputPlansToTaggedQueue(
        self: *State,
        allocator: std.mem.Allocator,
        calls: anytype,
        comptime entries: anytype,
        plans: []TrackedCallServiceActionPlan,
        output_messages: anytype,
        context: anytype,
        queue: anytype,
    ) !TrackedCallServiceActionStats {
        const stats = try self.dispatchWireCallServiceActionsUnified(allocator, calls, entries, plans, output_messages, context);
        _ = try appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(allocator, stats, plans[0..stats.actions()], output_messages, queue);
        return stats;
    }

    pub fn initTrackedCallServiceActionPlans(self: *const State, ids: []const QuestionId, comptime entries: anytype, plans: []TrackedCallServiceActionPlan) !TrackedCallServiceActionStats {
        const stats = try self.trackedCallServiceActionStats(ids, entries);
        try stats.validateActionCapacity(plans.len);
        var indexes = .{
            .dispatch = stats.dispatchRange().start,
            .forward = stats.forwardRange().start,
            .unimplemented = stats.unimplementedRange().start,
        };
        for (ids, 0..) |id, source_index| {
            if (try self.trackedCallServiceAction(id, entries)) |action| {
                storeServiceActionPlanByRange(stats, plans, &indexes, .{
                    .source_index = source_index,
                    .question_id = id,
                    .action = action,
                });
            }
        }
        return stats;
    }

    pub fn callMatchesCallMethod(self: *const State, id: QuestionId, method: CallMethod) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.matchesMethod(method);
    }

    pub fn callMatchesMethod(self: *const State, id: QuestionId, interface_id: u64, method_id: u16) ?bool {
        return self.callMatchesCallMethod(id, .{ .interface_id = interface_id, .method_id = method_id });
    }

    pub fn callMatchesWireCall(self: *const State, id: QuestionId, call: anytype) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.matchesWireCall(call);
    }

    pub fn callMatchesWireMessage(self: *const State, id: QuestionId, message: anytype) !?bool {
        const info = self.callInfo(id) orelse return null;
        return try info.matchesWireMessage(message);
    }

    pub fn callHasMethod(self: *const State, id: QuestionId) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.hasMethod();
    }

    pub fn callSendsResultsTo(self: *const State, id: QuestionId, target: CallSendResultsTo) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.sendsResultsTo(target);
    }

    pub fn callThirdPartyResultsUsage(self: *const State, id: QuestionId) ?AnyPointerUsage {
        const info = self.callInfo(id) orelse return null;
        return info.thirdPartyResultsUsage();
    }

    pub fn callHasThirdPartyResultsUsage(self: *const State, id: QuestionId) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.hasThirdPartyResultsUsage();
    }

    pub fn callOptions(self: *const State, id: QuestionId) ?CallOptions {
        const info = self.callInfo(id) orelse return null;
        return info.callOptions();
    }

    pub fn trackedCallDispatchInfo(self: *const State, id: QuestionId) Error!?TrackedCallDispatchInfo {
        const info = self.callInfo(id) orelse return null;
        return try self.dispatchInfoForCallInfo(info);
    }

    pub fn callAllowsThirdPartyTailCall(self: *const State, id: QuestionId) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.allowsThirdPartyTailCall();
    }

    pub fn callForbidsPromisePipelining(self: *const State, id: QuestionId) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.forbidsPromisePipelining();
    }

    pub fn callOnlyAllowsPromisePipeline(self: *const State, id: QuestionId) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.onlyAllowsPromisePipeline();
    }

    pub fn callInfoCount(self: *const State) usize {
        return self.calls.count();
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
        if (event == .disembargo) {
            _ = try self.applyDisembargoInfo(event.disembargo);
            return;
        }
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
    try testing.expect(call_event.isQuestionOpening());
    try testing.expect(!call_event.isAnswerResolving());
    const return_event = Event{ .return_ = 12 };
    try testing.expectEqual(MessageKind.return_, return_event.kind());
    try testing.expectEqual(@as(?AnswerId, 12), return_event.answerId());
    try testing.expect(return_event.isAnswerResolving());
    try testing.expect(!return_event.isQuestionClosing());

    const provide_event = Event{ .provide = 5 };
    try testing.expectEqual(MessageKind.provide, provide_event.kind());
    const provide_ref = provide_event.capabilityRef().?;
    try testing.expectEqual(CapabilityRef{ .export_id = 5 }, provide_ref);
    try testing.expect(provide_ref.isExport());
    try testing.expect(!provide_ref.isImport());
    try testing.expectEqual(@as(?ExportId, 5), provide_ref.exportId());
    try testing.expectEqual(@as(?ImportId, null), provide_ref.importId());
    try testing.expect(provide_ref.matchesExport(5));
    try testing.expect(!provide_ref.matchesImport(5));
    try testing.expect(provide_event.isCapabilityTableMutation());
    const accept_event = Event{ .accept = 6 };
    const accept_ref = accept_event.capabilityRef().?;
    try testing.expectEqual(CapabilityRef{ .import_id = 6 }, accept_ref);
    try testing.expect(accept_ref.isImport());
    try testing.expect(!accept_ref.isExport());
    try testing.expectEqual(@as(?ImportId, 6), accept_ref.importId());
    try testing.expectEqual(@as(?ExportId, null), accept_ref.exportId());
    try testing.expect(accept_ref.matchesImport(6));
    try testing.expect(!accept_ref.matchesExport(6));

    var stats: WireDispatchStats = .{};
    stats.recordResponseInitialized();
    stats.recordForwardRequired();
    stats.recordStateApplied();
    try testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try testing.expectEqual(@as(usize, 1), stats.forward_required);
    try testing.expectEqual(@as(usize, 1), stats.state_applied);
    try testing.expectEqual(@as(usize, 3), stats.total());
    try testing.expect(stats.initializedAnyResponse());
    try testing.expect(stats.requiredAnyForward());
    try testing.expect(stats.appliedAnyState());
    try testing.expect(stats.hasDenseResponses());
    try testing.expect(stats.hasDenseForwards());
    try testing.expect(stats.hasDenseOutputs());

    const forward_range = OutputRange{ .start = 2, .end = 5 };
    try testing.expectEqual(@as(usize, 3), forward_range.len());
    try testing.expectEqual(@as(?usize, 0), forward_range.localIndex(2));
    try testing.expectEqual(@as(?usize, 2), forward_range.localIndex(4));
    try testing.expect(forward_range.localIndex(5) == null);
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
    try testing.expect(return_event.return_.releasesParamCaps());
    try testing.expect(return_event.return_.needsFinish());

    const exception = ExceptionInfo{ .reason = "failed", .type_raw = @intFromEnum(ExceptionType.failed), .trace = "" };
    try testing.expectEqual(ExceptionType.failed, exception.exceptionType().?);
    try testing.expect(exception.isFailed());
    try testing.expect(exception.matchesType(.failed));
    try testing.expect(!exception.isOverloaded());
    try testing.expect((ExceptionInfo{ .reason = null, .type_raw = 999 }).exceptionType() == null);

    const third_party_answer = WireEvent{ .third_party_answer = 18 };
    try testing.expect(third_party_answer.isStateApplicable());
    try testing.expect(third_party_answer.isAnswerResolving());
    try testing.expect(third_party_answer.toStateEvent() == null);
    try testing.expectEqual(@as(?AnswerId, 18), third_party_answer.answerId());

    const release_event = WireEvent{ .release = .{ .id = 14, .reference_count = 3 } };
    try testing.expect(release_event.isCapabilityRelease());
    try testing.expectEqual(@as(?ImportId, 14), release_event.importId());
    try testing.expectEqual(@as(?u32, 3), release_event.releaseReferenceCount());
    try testing.expect(release_event.release.hasReferences());
    try testing.expect(!release_event.release.isSingleReference());
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

    const disembargo_event = WireEvent{ .disembargo = .{
        .target = .{ .imported_cap = 19 },
        .context = .{ .sender_loopback = 20 },
    } };
    try testing.expect(disembargo_event.isStateApplicable());
    try testing.expect(!disembargo_event.isQuestionOpening());
    try testing.expect(disembargo_event.toStateEvent() == null);
    try testing.expectEqual(DisembargoContext{ .sender_loopback = 20 }, disembargo_event.disembargo.context);
}

test "rpc question and answer trackers reject invalid transitions" {
    const testing = std.testing;

    var question = QuestionTracker{ .id = 7 };
    try testing.expect(question.state.isIdle());
    try testing.expect(question.isIdle());
    try testing.expect(question.canSend(.call));
    try question.open(.call);
    try testing.expect(question.state.isOpen());
    try testing.expect(question.isOpen());
    try testing.expect(!question.canSend(.bootstrap));
    try testing.expectError(error.QuestionAlreadyOpen, question.open(.bootstrap));
    try question.finish();
    try testing.expect(question.state.isFinished());
    try testing.expect(question.isFinished());
    try testing.expectError(error.QuestionNotOpen, question.finish());

    var answer = AnswerTracker{ .id = 9 };
    try testing.expect(answer.state.isUnresolved());
    try testing.expect(answer.isUnresolved());
    try answer.resolve(.return_);
    try testing.expect(answer.state.isResolved());
    try testing.expect(answer.isResolved());
    try testing.expectError(error.AnswerAlreadyResolved, answer.resolve(.resolve));
    try testing.expectError(error.InvalidTransition, answer.resolve(.call));

    var accept = AcceptTracker{
        .question_id = 10,
        .has_provision = true,
        .provision = .{ .max_capability_count = 3, .capability = 2 },
        .embargo = "embargo-10",
    };
    try testing.expect(accept.hasProvisionUsage());
    try testing.expect(accept.provisionMatchesCapability(2));
    try testing.expect(!accept.provisionMatchesCapability(1));
    try testing.expect(accept.hasEmbargo());
    try testing.expect(accept.matchesEmbargo("embargo-10"));
    try testing.expect(!accept.ready());
    accept.embargo_released = true;
    try testing.expect(accept.ready());

    const provide = ProvideTracker{
        .question_id = 11,
        .target = .{ .imported_cap = 12 },
        .has_recipient = true,
        .recipient = .{ .max_capability_count = 2, .capability = 1 },
    };
    try testing.expect(provide.hasRecipientUsage());
    try testing.expect(provide.recipientMatchesCapability(1));
    try testing.expect(!provide.recipientMatchesCapability(0));
    try testing.expect(provide.targetsImport(12));

    const join = JoinTracker{
        .question_id = 13,
        .target = .{ .promised_answer = .{ .question_id = 14 } },
        .has_key_part = true,
        .key_part = .{ .max_capability_count = 5, .capability = 4 },
    };
    try testing.expect(join.hasKeyPartUsage());
    try testing.expect(join.keyPartMatchesCapability(4));
    try testing.expect(!join.keyPartMatchesCapability(3));
    try testing.expect(join.targetsPromisedQuestion(14));
}

test "rpc capability trackers reject double release" {
    const testing = std.testing;

    var export_tracker = ExportTracker{ .id = 1 };
    try testing.expect(export_tracker.isLive());
    try testing.expect(!export_tracker.isResolved());
    try export_tracker.resolveTo(.{ .sender_hosted = 99 });
    try testing.expect(export_tracker.isResolved());
    try testing.expect(export_tracker.hasResolution());
    try export_tracker.release();
    try testing.expect(!export_tracker.isLive());
    try testing.expect(export_tracker.state.isReleased());
    try testing.expect(export_tracker.isReleased());
    try testing.expectError(error.ExportAlreadyReleased, export_tracker.release());

    var import_tracker = ImportTracker{ .id = 2 };
    try testing.expect(import_tracker.state.isLive());
    try import_tracker.release();
    try testing.expect(import_tracker.state.isReleased());
    try testing.expect(import_tracker.isReleased());
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
    try testing.expectEqual(@as(?MessageKind, .call), state.questionKind(1));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(1));
    try testing.expectEqual(StateQuestionStats{
        .questions = 1,
        .open_questions = 1,
        .answers = 1,
        .unresolved_answers = 1,
    }, state.questionStats());
    try testing.expectEqual(@as(usize, 2), state.questionStats().active());
    try testing.expectEqual(@as(usize, 2), state.questionStats().total());
    try testing.expect(state.questionStats().hasEntries());
    try testing.expect(!state.questionStats().isEmpty());
    try testing.expect((StateQuestionStats{}).isEmpty());
    try testing.expect(!(StateQuestionStats{}).hasEntries());
    try testing.expect(state.questionStats().hasQuestions());
    try testing.expect(state.questionStats().hasAnswers());
    try testing.expect(state.questionStats().hasOpenQuestions());
    try testing.expect(state.questionStats().hasUnresolvedAnswers());
    try testing.expect(state.questionStats().hasActive());
    try testing.expect(!state.questionStats().hasCompleteQuestions());

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
    try testing.expectEqual(@as(?MessageKind, .return_), state.answerKind(1));
    try testing.expect(state.answerComplete(1));
    try testing.expectError(error.AnswerAlreadyResolved, state.resolveAnswer(1, .resolve));
    try testing.expectError(error.QuestionNotOpen, state.resolveAnswer(99, .return_));

    try testing.expect(state.questionComplete(1));
    try testing.expect(state.questionReadyToForget(1));
    try testing.expect(state.canReuseQuestionId(1));
    try testing.expectEqual(StateQuestionStats{
        .questions = 1,
        .finished_questions = 1,
        .answers = 1,
        .resolved_answers = 1,
        .complete_questions = 1,
    }, state.questionStats());
    try testing.expect(!state.questionStats().hasActive());
    try testing.expect(state.questionStats().hasFinishedQuestions());
    try testing.expect(state.questionStats().hasResolvedAnswers());
    try testing.expect(state.questionStats().hasCompleteQuestions());
    try state.forgetQuestion(1);
    try testing.expect(!state.hasQuestion(1));
    try testing.expect(!state.hasAnswer(1));
    try testing.expectEqual(@as(usize, 0), state.questionCount());
    try testing.expectEqual(@as(usize, 0), state.answerCount());
    try testing.expectError(error.QuestionNotOpen, state.forgetQuestion(1));
    try state.openQuestion(1, .bootstrap);
    try testing.expectEqual(@as(usize, 1), state.questionCount());
    try testing.expectEqual(@as(usize, 1), state.answerCount());
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(1));
    try testing.expectEqual(@as(?MessageKind, .bootstrap), state.questionKind(1));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(1));
    try testing.expectEqual(@as(?MessageKind, null), state.answerKind(1));
    try testing.expect(!state.answerComplete(1));
    try testing.expect(!state.questionReadyToForget(1));
    try testing.expect(!state.canReuseQuestionId(1));

    try state.openQuestion(2, .call);
    try state.finishQuestion(2);
    try state.resolveAnswer(2, .return_);
    try state.openQuestion(3, .call);
    try state.finishQuestion(3);
    try state.resolveAnswer(3, .return_);
    try state.openQuestion(4, .call);
    try testing.expectEqual(@as(usize, 2), state.forgetCompletedQuestions());
    try testing.expect(!state.hasQuestion(2));
    try testing.expect(!state.hasAnswer(2));
    try testing.expect(!state.hasQuestion(3));
    try testing.expect(!state.hasAnswer(3));
    try testing.expect(state.hasQuestion(1));
    try testing.expect(state.hasQuestion(4));
    try testing.expectEqual(@as(usize, 0), state.forgetCompletedQuestions());
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
    try testing.expectEqual(StateCapabilityStats{
        .exports = 1,
        .live_exports = 1,
        .imports = 1,
        .live_imports = 1,
        .import_references = 1,
    }, state.capabilityStats());
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().live());
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().total());
    try testing.expect(state.capabilityStats().hasCapabilities());
    try testing.expect(!state.capabilityStats().isEmpty());
    try testing.expect((StateCapabilityStats{}).isEmpty());
    try testing.expect(!(StateCapabilityStats{}).hasCapabilities());
    try testing.expect(state.capabilityStats().hasExports());
    try testing.expect(state.capabilityStats().hasImports());
    try testing.expect(state.capabilityStats().hasLive());
    try testing.expect(state.capabilityStats().hasImportReferences());
    try testing.expect(!state.capabilityStats().hasReleased());

    try testing.expectError(error.InvalidTransition, state.addExport(10));
    try testing.expectError(error.InvalidTransition, state.addImport(20));
    try testing.expectError(error.InvalidTransition, state.releaseExport(99));
    try testing.expectError(error.InvalidTransition, state.releaseImport(99));

    try state.releaseExport(10);
    try state.releaseImport(20);
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.exportState(10));
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(20));
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().released());
    try testing.expect(state.capabilityStats().hasReleased());
    try testing.expectError(error.ExportAlreadyReleased, state.releaseExport(10));
    try testing.expectError(error.ImportAlreadyReleased, state.releaseImport(20));
    try state.forgetReleasedExport(10);
    try state.forgetReleasedImport(20);
    try testing.expect(!state.hasExport(10));
    try testing.expect(!state.hasImport(20));
    try testing.expectError(error.InvalidTransition, state.forgetReleasedExport(10));
    try testing.expectError(error.InvalidTransition, state.forgetReleasedImport(20));

    try state.addExport(11);
    try state.addExport(12);
    try state.addImport(21);
    try state.addImport(22);
    try state.releaseExport(11);
    try state.releaseImport(21);
    try state.resolveExportTo(12, null);
    try state.resolveImportTo(22, null);
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().resolved());
    try testing.expect(state.capabilityStats().hasResolved());
    const removed = state.forgetReleasedCapabilities();
    try testing.expectEqual(@as(usize, 1), removed.exports);
    try testing.expectEqual(@as(usize, 1), removed.imports);
    try testing.expect(!state.hasExport(11));
    try testing.expect(state.hasExport(12));
    try testing.expect(!state.hasImport(21));
    try testing.expect(state.hasImport(22));
    try testing.expectEqual(@as(usize, 0), state.forgetReleasedExports());
    try testing.expectEqual(@as(usize, 0), state.forgetReleasedImports());
}

test "rpc state cleanup forgets completed and released entries" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.openQuestion(100, .call);
    try state.finishQuestion(100);
    try state.resolveAnswer(100, .return_);
    try state.openQuestion(101, .call);
    try state.addExport(200);
    try state.addImport(300);
    try state.releaseExport(200);
    try state.releaseImport(300);

    const cleaned = state.cleanup();
    try testing.expectEqual(@as(usize, 1), cleaned.questions);
    try testing.expectEqual(@as(usize, 1), cleaned.exports);
    try testing.expectEqual(@as(usize, 1), cleaned.imports);
    try testing.expectEqual(@as(usize, 3), cleaned.total());
    try testing.expect(cleaned.hasWork());
    try testing.expect(!cleaned.isEmpty());
    try testing.expect(cleaned.hasQuestionWork());
    try testing.expect(cleaned.hasExportWork());
    try testing.expect(cleaned.hasImportWork());
    try testing.expect(cleaned.hasCapabilityWork());
    try testing.expect(!state.hasQuestion(100));
    try testing.expect(state.hasQuestion(101));
    try testing.expect(!state.hasExport(200));
    try testing.expect(!state.hasImport(300));
    const clean_again = state.cleanup();
    try testing.expectEqual(@as(usize, 0), clean_again.total());
    try testing.expect(!clean_again.hasWork());
    try testing.expect(clean_again.isEmpty());
    try testing.expect(!clean_again.hasQuestionWork());
    try testing.expect(!clean_again.hasExportWork());
    try testing.expect(!clean_again.hasImportWork());
    try testing.expect(!clean_again.hasCapabilityWork());
}

test "rpc state applies capability descriptors to table lifetimes" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    const none_descriptor: CapDescriptor = .none;
    try testing.expect(none_descriptor.isNone());
    try testing.expect(!none_descriptor.isForwardableToCallTarget());
    try testing.expectEqual(@as(?ExportId, null), none_descriptor.exportedId());
    try testing.expectEqual(@as(?ImportId, null), none_descriptor.importedId());

    const sender_descriptor = CapDescriptor{ .sender_hosted = 30 };
    try testing.expect(sender_descriptor.isSenderHosted());
    try testing.expect(!sender_descriptor.isReceiverHosted());
    try testing.expectEqual(@as(?ExportId, 30), sender_descriptor.exportedId());
    try testing.expectEqual(@as(?ImportId, null), sender_descriptor.importedId());
    try testing.expect(sender_descriptor.isForwardableToCallTarget());
    try testing.expectEqual(CallTarget{ .imported_cap = 30 }, sender_descriptor.forwardableCallTarget().?);

    const receiver_descriptor = CapDescriptor{ .receiver_hosted = 31 };
    try testing.expect(receiver_descriptor.isReceiverHosted());
    try testing.expectEqual(@as(?ImportId, 31), receiver_descriptor.importedId());
    try testing.expect(!receiver_descriptor.isForwardableToCallTarget());

    const answer_descriptor = CapDescriptor{ .receiver_answer = .{ .question_id = 32 } };
    try testing.expect(answer_descriptor.isReceiverAnswer());
    try testing.expectEqual(PromisedAnswerTarget{ .question_id = 32 }, answer_descriptor.promisedAnswer().?);
    try testing.expectEqual(CallTarget{ .promised_answer = .{ .question_id = 32 } }, answer_descriptor.forwardableCallTarget().?);

    const sender_promise_descriptor = CapDescriptor{ .sender_promise = 33 };
    try testing.expect(sender_promise_descriptor.isSenderPromise());
    try testing.expectEqual(@as(?ExportId, 33), sender_promise_descriptor.exportedId());

    const third_party_descriptor = CapDescriptor{ .third_party_hosted = 34 };
    try testing.expect(third_party_descriptor.isThirdPartyHosted());
    try testing.expectEqual(@as(?ExportId, 34), third_party_descriptor.exportedId());

    try state.applyCapDescriptor(.{ .sender_hosted = 30 });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(30));
    try testing.expectEqual(@as(?u32, 1), state.importReferenceCount(30));
    try state.applyCapDescriptor(.{ .sender_promise = 30 });
    try testing.expectEqual(@as(?u32, 2), state.importReferenceCount(30));
    try state.applyCapDescriptor(.{ .third_party_hosted = 30 });
    try testing.expectEqual(@as(?u32, 3), state.importReferenceCount(30));

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

    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .disembargo = .{
        .target = .{ .imported_cap = 43 },
        .context = .{ .sender_loopback = 44 },
    } }));
    try state.addImport(43);
    try state.applyWireEvent(.{ .disembargo = .{
        .target = .{ .imported_cap = 43 },
        .context = .{ .sender_loopback = 44 },
    } });

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
    try testing.expectEqual(@as(usize, 0), state.provideCount());

    const accept = WireEvent{ .accept = 72 };
    try testing.expect(accept.toStateEvent() == null);
    try state.applyWireEvent(accept);
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(72));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(72));
    try testing.expectEqual(@as(usize, 0), state.acceptCount());

    const join = WireEvent{ .join = 73 };
    try testing.expect(join.toStateEvent() == null);
    try state.applyWireEvent(join);
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(73));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(73));
    try testing.expectEqual(@as(usize, 0), state.joinCount());

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
    try testing.expect(state.exportResolution(48) == null);
    try state.applyWireEvent(.{ .resolve = 48 });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.exportState(48));
    try testing.expectEqual(@as(?bool, true), state.exportResolved(48));
    try testing.expect(state.exportResolution(48) == null);
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
