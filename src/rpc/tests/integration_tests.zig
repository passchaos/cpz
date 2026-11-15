const std = @import("std");
const rpc = @import("../../rpc.zig");

const AcceptTracker = rpc.AcceptTracker;
const AnswerId = rpc.AnswerId;
const AnswerState = rpc.AnswerState;
const AnswerTracker = rpc.AnswerTracker;
const CallTarget = rpc.CallTarget;
const CapDescriptor = rpc.CapDescriptor;
const CapabilityLifetime = rpc.CapabilityLifetime;
const CapabilityRef = rpc.CapabilityRef;
const DisembargoContext = rpc.DisembargoContext;
const Event = rpc.Event;
const ExceptionInfo = rpc.ExceptionInfo;
const ExceptionType = rpc.ExceptionType;
const ExportId = rpc.ExportId;
const ExportTracker = rpc.ExportTracker;
const ImportId = rpc.ImportId;
const ImportTracker = rpc.ImportTracker;
const JoinTracker = rpc.JoinTracker;
const MessageKind = rpc.MessageKind;
const OutputRange = rpc.OutputRange;
const PromisedAnswerTarget = rpc.PromisedAnswerTarget;
const ProvideTracker = rpc.ProvideTracker;
const QuestionId = rpc.QuestionId;
const QuestionState = rpc.QuestionState;
const QuestionTracker = rpc.QuestionTracker;
const State = rpc.State;
const StateCapabilityStats = rpc.StateCapabilityStats;
const StateQuestionStats = rpc.StateQuestionStats;
const WireDispatchStats = rpc.WireDispatchStats;
const WireEvent = rpc.WireEvent;
const WireMessageTag = rpc.WireMessageTag;

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
