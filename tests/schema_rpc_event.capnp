@0xb9f084cf6a5f3d31;

using QuestionId = UInt32;
using AnswerId = QuestionId;
using ExportId = UInt32;
using ImportId = ExportId;

struct Message {
  union {
    unimplemented @0 :Void;
    abort @1 :Void;

    bootstrap @8 :Bootstrap;
    call @2 :Call;
    return @3 :Return;
    finish @4 :Finish;

    resolve @5 :Resolve;
    release @6 :Release;
    disembargo @13 :Void;

    obsoleteSave @7 :Void;
    obsoleteDelete @9 :Void;

    provide @10 :Provide;
    accept @11 :Accept;
    thirdPartyAnswer @14 :ThirdPartyAnswer;

    join @12 :Join;
  }
}

struct Bootstrap {
  questionId @0 :QuestionId;
}

struct Call {
  questionId @0 :QuestionId;
  target @1 :MessageTarget;
  params @4 :Payload;
}

struct Return {
  answerId @0 :AnswerId;
  releaseParamCaps @1 :Bool = true;
  results @2 :Payload;
  noFinishNeeded @8 :Bool = false;
}

struct Finish {
  questionId @0 :QuestionId;
  releaseResultCaps @1 :Bool = true;
}

struct Resolve {
  promiseId @0 :ExportId;
}

struct Release {
  id @0 :ImportId;
  referenceCount @1 :UInt32;
}

struct Provide {
  questionId @0 :QuestionId;
  target @1 :MessageTarget;
}

struct Accept {
  questionId @0 :QuestionId;
}

struct ThirdPartyAnswer {
  answerId @0 :AnswerId;
}

struct Join {
  questionId @0 :QuestionId;
  target @1 :MessageTarget;
}

struct MessageTarget {
  union {
    importedCap @0 :ImportId;
    promisedAnswer @1 :PromisedAnswer;
  }
}

struct PromisedAnswer {
  questionId @0 :QuestionId;

  struct Op {
    union {
      noop @0 :Void;
      getPointerField @1 :UInt16;
    }
  }

  transform @1 :List(Op);
}

struct Payload {
  content @0 :AnyPointer;
  capTable @1 :List(CapDescriptor);
}

struct CapDescriptor {
  union {
    none @0 :Void;
    senderHosted @1 :ExportId;
    senderPromise @2 :ExportId;
    receiverHosted @3 :ImportId;
    receiverAnswer @4 :PromisedAnswer;
  }
}
