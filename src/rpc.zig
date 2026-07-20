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

pub const ExceptionInfo = struct {
    reason: ?[]const u8,
    type_raw: u16,
    trace: ?[]const u8 = null,
};

pub const ReturnOutcome = union(enum) {
    results,
    exception: ExceptionInfo,
    canceled,
    results_sent_elsewhere,
    take_from_other_question: QuestionId,
    await_from_third_party: AnyPointerUsage,
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
};

pub const WireDispatchOutcome = enum {
    response_initialized,
    /// The call target has already been resolved to another capability. The
    /// dispatcher recorded the inbound call in state, but deliberately did not
    /// initialize a response or invoke the local application handler; the
    /// transport/runtime layer should forward the original call instead.
    forward_required,
    state_applied,
};

pub const OutputRange = struct {
    start: usize,
    end: usize,

    pub fn len(self: @This()) usize {
        return self.end - self.start;
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
};

pub const StateCleanupStats = struct {
    questions: usize = 0,
    exports: usize = 0,
    imports: usize = 0,

    pub fn total(self: @This()) usize {
        return self.questions + self.exports + self.imports;
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

    pub fn ready(self: @This()) usize {
        return self.provide_recipients + self.ready_accept_provisions + self.join_key_parts;
    }

    pub fn blocked(self: @This()) usize {
        return self.pending_accept_embargos;
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
};

pub const HandoffReturnCapability = struct {
    question_id: QuestionId,
    export_id: ExportId,
};

pub const HandoffReturn = union(enum) {
    provide: HandoffReturnCapability,
    accept: HandoffReturnCapability,
    join: HandoffReturnCapability,
};

pub const HandoffReturnPlan = struct {
    provides: []const HandoffReturnCapability = &.{},
    accepts: []const HandoffReturnCapability = &.{},
    joins: []const HandoffReturnCapability = &.{},

    pub fn total(self: @This()) usize {
        return self.provides.len + self.accepts.len + self.joins.len;
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

    pub fn total(self: @This()) usize {
        return self.provides + self.accepts + self.joins;
    }

    pub fn validateCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.total()) return error.InvalidTransition;
    }
};

pub const RpcTurnPlan = struct {
    dispatch: WireDispatchStats = .{},
    handoff_returns: StateHandoffReturnStats = .{},
    pending_disembargos: usize = 0,

    pub fn responseMessages(self: @This()) usize {
        return self.dispatch.response_initialized + self.handoff_returns.total();
    }

    pub fn forwardedMessages(self: @This()) usize {
        return self.dispatch.forward_required;
    }

    pub fn stateOnlyMessages(self: @This()) usize {
        return self.dispatch.state_applied;
    }

    pub fn disembargoMessages(self: @This()) usize {
        return self.pending_disembargos;
    }

    pub fn totalOutputMessages(self: @This()) usize {
        return self.responseMessages() + self.forwardedMessages() + self.disembargoMessages();
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
};

pub fn rpcTurnUnifiedOutputPosition(turn_plan: RpcTurnPlan, output_index: usize) ?RpcTurnOutputPosition {
    const response_end = turn_plan.responseMessages();
    if (output_index < response_end) return .{ .role = .response, .local_index = output_index };

    const forward_end = response_end + turn_plan.forwardedMessages();
    if (output_index < forward_end) return .{ .role = .forward, .local_index = output_index - response_end };

    const total_end = forward_end + turn_plan.disembargoMessages();
    if (output_index < total_end) return .{ .role = .disembargo, .local_index = output_index - forward_end };

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
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    for (output_messages[0..turn_plan.totalOutputMessages()]) |output_message| {
        try sink_handler(sink_context, output_message);
    }
}

/// Send initialized unified turn outputs to a single callback while tagging
/// each message with its role and role-local index.
///
/// This is useful for transports that keep one physical enqueue path but still
/// need to distinguish locally-produced Returns from forwarded Calls and
/// Disembargo traffic without decoding the message union after it is built.
pub fn sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan: RpcTurnPlan, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    for (output_messages[0..turn_plan.totalOutputMessages()], 0..) |output_message, output_index| {
        try sink_handler(sink_context, rpcTurnUnifiedOutputPosition(turn_plan, output_index).?, output_message);
    }
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

    pub fn released(self: @This()) usize {
        return self.released_exports + self.released_imports;
    }

    pub fn resolved(self: @This()) usize {
        return self.resolved_exports + self.resolved_imports;
    }
};

pub const AnyPointerUsage = struct {
    max_capability_count: usize,
    capability: ?u32 = null,
};

fn validateAnyPointerUsageCapability(usage: AnyPointerUsage) Error!void {
    if (usage.capability) |index| {
        if (@as(usize, index) >= usage.max_capability_count) return error.InvalidTransition;
    }
}

pub const AcceptInfo = struct {
    question_id: QuestionId,
    has_provision: bool,
    provision_max_capability_count: usize,
    provision_capability: ?u32 = null,
    embargo: ?[]const u8,
};

pub const ProvideInfo = struct {
    question_id: QuestionId,
    target: CallTarget,
    has_recipient: bool,
    recipient_max_capability_count: usize,
    recipient_capability: ?u32 = null,
};

pub const JoinInfo = struct {
    question_id: QuestionId,
    target: CallTarget,
    has_key_part: bool,
    key_part_max_capability_count: usize,
    key_part_capability: ?u32 = null,
};

pub const ThirdPartyAnswerInfo = struct {
    answer_id: AnswerId,
    has_completion: bool,
    completion: ?AnyPointerUsage = null,
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
};

pub const CallInfo = struct {
    question_id: QuestionId,
    target: CallTarget,
    method: CallMethod,
    send_results_to: CallSendResultsTo,
    send_results_to_third_party: ?AnyPointerUsage = null,
    flags: CallFlags,

    pub fn matchesMethod(self: @This(), method: CallMethod) bool {
        return self.method.matches(method.interface_id, method.method_id);
    }

    pub fn sendsResultsTo(self: @This(), target: CallSendResultsTo) bool {
        return self.send_results_to == target;
    }

    pub fn thirdPartyResultsUsage(self: @This()) ?AnyPointerUsage {
        return if (self.send_results_to == .third_party) self.send_results_to_third_party else null;
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
        return self.flags.allow_third_party_tail_call;
    }

    pub fn forbidsPromisePipelining(self: @This()) bool {
        return self.flags.no_promise_pipelining;
    }

    pub fn onlyAllowsPromisePipeline(self: @This()) bool {
        return self.flags.only_promise_pipeline;
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
};

pub const TrackedCallServiceActionPlan = struct {
    source_index: usize,
    question_id: QuestionId,
    action: TrackedCallServiceAction,
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

    pub fn responseMessages(self: @This()) usize {
        return self.dispatch + self.unimplemented;
    }

    pub fn total(self: @This()) usize {
        return self.actions() + self.missing + self.skipped;
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
};

pub const TrackedCallServiceActionOutputRole = enum {
    response,
    forward,
};

pub const TrackedCallServiceActionOutputPosition = struct {
    role: TrackedCallServiceActionOutputRole,
    local_index: usize,
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
};

pub const DisembargoInfo = struct {
    target: CallTarget,
    context: DisembargoContext,
};

pub const DisembargoApplyInfo = struct {
    released_accepts: usize = 0,
    released_accept_ids: []const QuestionId = &.{},

    pub fn releasedAnyAccept(self: @This()) bool {
        return self.released_accepts != 0;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.released_accept_ids);
        self.* = undefined;
    }
};

pub const PendingAcceptEmbargo = struct {
    question_id: QuestionId,
    embargo: []const u8,
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
};

pub const WireMessageApplyResult = union(enum) {
    state_applied,
    disembargo: DisembargoApplyInfo,

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

pub const CallSendResultsTo = enum {
    caller,
    yourself,
    third_party,
};

pub const CallFlags = struct {
    allow_third_party_tail_call: bool = false,
    no_promise_pipelining: bool = false,
    only_promise_pipeline: bool = false,
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

        pub fn callOptions(self: @This()) CallOptions {
            return self.method.callOptions();
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

    pub fn validate(self: @This()) Error!void {
        if (self.send_results_to_third_party != null and self.send_results_to != .third_party) return error.InvalidTransition;
        if (self.send_results_to_third_party) |usage| try validateAnyPointerUsageCapability(usage);
    }

    pub fn callMethod(self: @This()) CallMethod {
        return self.method;
    }

    pub fn matchesMethod(self: @This(), method: CallMethod) bool {
        return self.method.matches(method.interface_id, method.method_id);
    }

    pub fn methodEntry(self: @This(), handler: anytype) CallMethodEntry(@TypeOf(handler)) {
        return self.method.methodEntry(handler);
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

    pub fn allowsThirdPartyTailCall(self: @This()) bool {
        return self.flags.allow_third_party_tail_call;
    }

    pub fn forbidsPromisePipelining(self: @This()) bool {
        return self.flags.no_promise_pipelining;
    }

    pub fn onlyAllowsPromisePipeline(self: @This()) bool {
        return self.flags.only_promise_pipeline;
    }
};

pub const CapDescriptor = union(enum) {
    none,
    sender_hosted: ExportId,
    sender_promise: ExportId,
    receiver_hosted: ImportId,
    receiver_answer: PromisedAnswerTarget,
    third_party_hosted: ExportId,
};

pub const CapDescriptorInfo = struct {
    descriptor: CapDescriptor,
    attached_fd: u8 = 0xff,
    third_party_contact: ?AnyPointerUsage = null,
};

pub fn callTargetFromForwardableCapDescriptor(descriptor: CapDescriptor) ?CallTarget {
    return switch (descriptor) {
        .sender_hosted, .sender_promise, .third_party_hosted => |id| .{ .imported_cap = id },
        .receiver_answer => |answer| .{ .promised_answer = answer },
        .none, .receiver_hosted => null,
    };
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

pub const WireEvent = union(WireMessageTag) {
    unimplemented: void,
    abort: void,
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
    if (!info.has_provision and info.provision_capability != null) return error.InvalidTransition;
    if (info.has_provision and info.provision_capability == null) return error.InvalidTransition;
    if (info.has_provision) try validateAnyPointerUsageCapability(.{
        .max_capability_count = info.provision_max_capability_count,
        .capability = info.provision_capability,
    });
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
    if (!info.has_recipient and info.recipient_capability != null) return error.InvalidTransition;
    if (info.has_recipient and info.recipient_capability == null) return error.InvalidTransition;
    if (info.has_recipient) try validateAnyPointerUsageCapability(.{
        .max_capability_count = info.recipient_max_capability_count,
        .capability = info.recipient_capability,
    });
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
    if (!info.has_key_part and info.key_part_capability != null) return error.InvalidTransition;
    if (info.has_key_part and info.key_part_capability == null) return error.InvalidTransition;
    if (info.has_key_part) try validateAnyPointerUsageCapability(.{
        .max_capability_count = info.key_part_max_capability_count,
        .capability = info.key_part_capability,
    });
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
    if (!info.has_completion and info.completion != null) return error.InvalidTransition;
    if (info.has_completion and (info.completion == null or info.completion.?.capability == null)) return error.InvalidTransition;
    if (info.completion) |completion| try validateAnyPointerUsageCapability(completion);
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
    const has_cap = info.cap != null;
    const has_exception = info.exception != null;
    if (has_cap == has_exception) return error.InvalidTransition;

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
    if (info.third_party_contact != null and info.descriptor != .third_party_hosted) return error.InvalidTransition;
    if (info.third_party_contact) |contact| try validateAnyPointerUsageCapability(contact);
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
    try stats.validateActionCapacity(output_messages.len);
    for (output_messages[0..stats.actions()]) |message| try sink_handler(sink_context, message);
}

pub fn sendRpcServiceActionUnifiedOutputsToTaggedSink(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    try stats.validateActionCapacity(output_messages.len);
    for (output_messages[0..stats.actions()], 0..) |message, output_index| {
        try sink_handler(sink_context, trackedCallServiceActionUnifiedOutputPosition(stats, output_index).?, message);
    }
}

pub fn sendRpcServiceActionUnifiedOutputsToSinks(
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !void {
    try stats.validateActionCapacity(output_messages.len);
    for (try stats.outputResponseRange().slice(output_messages)) |message| try response_handler(response_context, message);
    for (try stats.outputForwardRange().slice(output_messages)) |message| try forward_handler(forward_context, message);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSink(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !void {
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
}

pub fn sendRpcServiceActionUnifiedOutputPlansToTaggedSink(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !void {
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
    try options.validate();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try writeCallMethodToWire(options.method, call);
    if (options.send_results_to_third_party) |usage|
        try writeSendResultsToThirdPartyToWire(call, usage)
    else
        try writeSendResultsToToWire(options.send_results_to, call);
    try writeCallFlagsToWire(options.flags, call);
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.trackCallInfo(.{
        .question_id = question_id,
        .target = target,
        .method = options.method,
        .send_results_to = options.send_results_to,
        .send_results_to_third_party = options.send_results_to_third_party,
        .flags = options.flags,
    });
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
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
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
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
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

pub fn dispatchCallMethods(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    comptime entries: anytype,
) !void {
    try validateCallMethodEntries(entries);
    const method = callMethodFromWireCall(call);
    inline for (entries) |entry| {
        if (method.matches(entry.method.interface_id, entry.method.method_id)) {
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
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
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
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethods(state, allocator, response_message, call, context, entries);
    return .response_initialized;
}

pub fn planWireMessageDispatch(state: *const State, request_message: anytype) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => return .response_initialized,
        .call => {
            const call = try request_message.call();
            try state.validateWireCallTarget(call);
            return if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null)
                .forward_required
            else
                .response_initialized;
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
        const method = callMethodFromWireCall(call);
        const send_results_to = try sendResultsToFromWireCall(call);
        const send_results_to_third_party = try sendResultsToThirdPartyUsageFromWireCall(call);
        if (send_results_to_third_party) |usage| try validateAnyPointerUsageCapability(usage);
        const flags = callFlagsFromWireCall(call);
        const descriptors = try capTableFromWireCallParams(allocator, call);
        defer allocator.free(descriptors);

        try self.validateCallTarget(target);
        try validateWirePayloadContent(try call.params(), descriptors.len);
        for (descriptors) |descriptor| try self.validateCapDescriptor(descriptor);
        try self.openQuestion(question_id, .call);
        try self.trackCallInfo(.{
            .question_id = question_id,
            .target = target,
            .method = method,
            .send_results_to = send_results_to,
            .send_results_to_third_party = send_results_to_third_party,
            .flags = flags,
        });
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

    pub fn provideInfo(self: *const State, id: QuestionId) ?ProvideInfo {
        const tracker = self.provides.get(id) orelse return null;
        return tracker.info();
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

    pub fn readyHandoffReturnsAlloc(self: *const State, allocator: std.mem.Allocator, plan: HandoffReturnPlan) (Error || std.mem.Allocator.Error)![]HandoffReturn {
        var completions = try allocator.alloc(HandoffReturn, plan.total());
        errdefer allocator.free(completions);
        var index: usize = 0;
        for (plan.provides) |value| {
            _ = self.provideRecipient(value.question_id) orelse return error.InvalidTransition;
            completions[index] = .{ .provide = value };
            index += 1;
        }
        for (plan.accepts) |value| {
            _ = self.readyAcceptProvision(value.question_id) orelse return error.InvalidTransition;
            completions[index] = .{ .accept = value };
            index += 1;
        }
        for (plan.joins) |value| {
            _ = self.joinKeyPart(value.question_id) orelse return error.InvalidTransition;
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

    pub fn initTrackedHandoffReturnMessages(self: *const State, response_messages: anytype, completions: []const HandoffReturn) !StateHandoffReturnStats {
        if (response_messages.len < completions.len) return error.InvalidTransition;
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            stats.record(completion);
        }
        return stats;
    }

    pub fn initReadyHandoffReturnPlanMessages(self: *const State, response_messages: anytype, plan: HandoffReturnPlan) !StateHandoffReturnStats {
        if (response_messages.len < plan.total()) return error.InvalidTransition;
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
        var stats: StateHandoffReturnStats = .{};
        for (completions, 0..) |completion, index| {
            try self.initTrackedHandoffReturnMessage(response_messages[index], completion);
            try sink_handler(sink_context, response_messages[index]);
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
        if (dispatch_info.transitive_forward_target) |target| return .{ .forward = target };
        if (try dispatch_info.info.method.entryIndex(entries)) |index| return .{ .dispatch = index };
        return .unimplemented;
    }

    pub fn wireCallServiceAction(self: *const State, call: anytype, comptime entries: anytype) !TrackedCallServiceAction {
        try self.validateWireCallTarget(call);
        if (try self.wireCallTargetTransitiveForwardTarget(call)) |target| return .{ .forward = target };
        if (try callMethodFromWireCall(call).entryIndex(entries)) |index| return .{ .dispatch = index };
        return .unimplemented;
    }

    pub fn wireCallServiceActionStats(self: *const State, calls: anytype, comptime entries: anytype) !TrackedCallServiceActionStats {
        var stats: TrackedCallServiceActionStats = .{};
        for (calls) |call| stats.record(try self.wireCallServiceAction(call, entries));
        return stats;
    }

    pub fn wireMessageServiceActionStats(self: *const State, messages: anytype, comptime entries: anytype) !TrackedCallServiceActionStats {
        var stats: TrackedCallServiceActionStats = .{};
        for (messages) |message| {
            switch (try eventFromWireMessage(message)) {
                .call => stats.record(try self.wireCallServiceAction(try message.call(), entries)),
                else => stats.recordSkipped(),
            }
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
            switch (try eventFromWireMessage(message)) {
                .call => storeServiceActionByRange(stats, actions, &indexes, try self.wireCallServiceAction(try message.call(), entries)),
                else => {},
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
            switch (try eventFromWireMessage(message)) {
                .call => {
                    const call = try message.call();
                    const action = try self.wireCallServiceAction(call, entries);
                    storeServiceActionPlanByRange(stats, plans, &indexes, .{
                        .source_index = source_index,
                        .question_id = call.questionId(),
                        .action = action,
                    });
                },
                else => {},
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

    pub fn callSendsResultsTo(self: *const State, id: QuestionId, target: CallSendResultsTo) ?bool {
        const info = self.callInfo(id) orelse return null;
        return info.sendsResultsTo(target);
    }

    pub fn callThirdPartyResultsUsage(self: *const State, id: QuestionId) ?AnyPointerUsage {
        const info = self.callInfo(id) orelse return null;
        return info.thirdPartyResultsUsage();
    }

    pub fn callOptions(self: *const State, id: QuestionId) ?CallOptions {
        const info = self.callInfo(id) orelse return null;
        return info.callOptions();
    }

    pub fn trackedCallDispatchInfo(self: *const State, id: QuestionId) Error!?TrackedCallDispatchInfo {
        const info = self.callInfo(id) orelse return null;
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
    const return_event = Event{ .return_ = 12 };
    try testing.expectEqual(MessageKind.return_, return_event.kind());
    try testing.expectEqual(@as(?AnswerId, 12), return_event.answerId());

    const provide_event = Event{ .provide = 5 };
    try testing.expectEqual(MessageKind.provide, provide_event.kind());
    try testing.expectEqual(CapabilityRef{ .export_id = 5 }, provide_event.capabilityRef().?);
    const accept_event = Event{ .accept = 6 };
    try testing.expectEqual(CapabilityRef{ .import_id = 6 }, accept_event.capabilityRef().?);

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
    try testing.expectEqual(@as(?MessageKind, .call), state.questionKind(1));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(1));
    try testing.expectEqual(StateQuestionStats{
        .questions = 1,
        .open_questions = 1,
        .answers = 1,
        .unresolved_answers = 1,
    }, state.questionStats());
    try testing.expectEqual(@as(usize, 2), state.questionStats().active());

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

    try testing.expectError(error.InvalidTransition, state.addExport(10));
    try testing.expectError(error.InvalidTransition, state.addImport(20));
    try testing.expectError(error.InvalidTransition, state.releaseExport(99));
    try testing.expectError(error.InvalidTransition, state.releaseImport(99));

    try state.releaseExport(10);
    try state.releaseImport(20);
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.exportState(10));
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(20));
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().released());
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
    try testing.expect(!state.hasQuestion(100));
    try testing.expect(state.hasQuestion(101));
    try testing.expect(!state.hasExport(200));
    try testing.expect(!state.hasImport(300));
    try testing.expectEqual(@as(usize, 0), state.cleanup().total());
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
