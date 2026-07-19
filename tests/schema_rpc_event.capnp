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
    disembargo @13 :Disembargo;

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
  allowThirdPartyTailCall @8 :Bool = false;
  noPromisePipelining @9 :Bool = false;
  onlyPromisePipeline @10 :Bool = false;

  union {
    sendResultsTo_caller @5 :Void;
    sendResultsTo_yourself @6 :Void;
  }
}

struct Return {
  answerId @0 :AnswerId;
  releaseParamCaps @1 :Bool = true;
  noFinishNeeded @8 :Bool = false;

  union {
    results @2 :Payload;
    exception @3 :Exception;
    canceled @4 :Void;
    resultsSentElsewhere @5 :Void;
    takeFromOtherQuestion @6 :QuestionId;
    awaitFromThirdParty @7 :AnyPointer;
  }
}

struct Finish {
  questionId @0 :QuestionId;
  releaseResultCaps @1 :Bool = true;
}

struct Resolve {
  promiseId @0 :ExportId;

  union {
    cap @1 :CapDescriptor;
    exception @2 :Exception;
  }
}

struct Release {
  id @0 :ImportId;
  referenceCount @1 :UInt32;
}

struct Disembargo {
  target @0 :MessageTarget;

  union {
    senderLoopback @1 :UInt32;
    receiverLoopback @2 :UInt32;
    accept @3 :Data;
  }
}

struct Provide {
  questionId @0 :QuestionId;
  target @1 :MessageTarget;
  recipient @2 :AnyPointer;
}

struct Accept {
  questionId @0 :QuestionId;
  provision @1 :AnyPointer;
  embargo @2 :Data;
}

struct ThirdPartyAnswer {
  answerId @0 :AnswerId;
}

struct Join {
  questionId @0 :QuestionId;
  target @1 :MessageTarget;
  keyPart @2 :AnyPointer;
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
    thirdPartyHosted @5 :ThirdPartyCapDescriptor;
  }
}

struct ThirdPartyCapDescriptor {
  vineId @1 :ExportId;
}

struct Exception {
  reason @0 :Text;
  type @3 :Type;

  enum Type {
    failed @0;
    overloaded @1;
    disconnected @2;
    unimplemented @3;
  }
}
