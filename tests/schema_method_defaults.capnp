enum Mode {
  off @0;
  on @1;
}

const referencedText :Text = "referenced text";
const referencedData :Data = 0x"12 34";
const referencedFlag :Bool = true;
const referencedAmount :UInt32 = 123;
const referencedRatio :Float64 = +1.25e2;
const referencedMode :Mode = on;
const referencedNumbers :List(UInt16) = [7, 8];
const referencedCaps :List(Capability) = [void, null];
const referencedCallbacks :List(TopCallback) = [void];

interface TopCallback {
  ping @0 () -> ();
}

using MaybeCallbacks = List(?TopCallback);

struct MaybeDefaults {
  absent @0 :?Text = null;
  absentData @1 :?Data = null;
  maybeNumbers @2 :?List(UInt16) = null;
  maybeItem @3 :?Defaults.Item = null;
  maybeAny @4 :?AnyPointer = null;
  maybeAnyStruct @5 :?AnyStruct = null;
  maybeAnyList @6 :?AnyList = null;
}

struct OptionalBlobLists {
  labels @0 :List(?Text);
  payloads @1 :List(?Data);
  caps @2 :List(?Capability);
  anyValues @3 :List(?AnyPointer);
  anyStructs @4 :List(?AnyStruct);
  anyLists @5 :List(?AnyList);
  callbacks @6 :List(?TopCallback);
  items @7 :List(?Defaults.Item);
}

struct NullPointerDefaults {
  text @0 :Text = null;
  data @1 :Data = null;
  numbers @2 :List(UInt16) = null;
  item @3 :Defaults.Item = null;
  cap @4 :Capability = void;
  callback @5 :TopCallback = void;
}

struct ConstRefDefaults {
  const localText :Text = "local text";
  const localData :Data = 0x"56 78";
  const localFlag :Bool = false;
  const localAmount :UInt32 = 456;
  const localRatio :Float64 = -2.5;
  const localMode :Mode = off;
  const localNumbers :List(UInt16) = [9, 10];

  text @0 :Text = referencedText;
  data @1 :Data = referencedData;
  localTextField @2 :Text = localText;
  localDataField @3 :Data = localData;
  flag @4 :Bool = referencedFlag;
  amount @5 :UInt32 = referencedAmount;
  ratio @6 :Float64 = referencedRatio;
  mode @7 :Mode = referencedMode;
  localFlagField @8 :Bool = localFlag;
  localAmountField @9 :UInt32 = localAmount;
  localRatioField @10 :Float64 = localRatio;
  localModeField @11 :Mode = localMode;
  numbers @12 :List(UInt16) = referencedNumbers;
  localNumbersField @13 :List(UInt16) = localNumbers;
  item @14 :Defaults.Item = referencedItem;
  any @15 :AnyPointer = referencedItem;
  anyStruct @16 :AnyStruct = referencedItem;
  anyList @17 :AnyList = referencedNumbers;
  capList @18 :List(Capability) = referencedCaps;
  callbackList @19 :List(TopCallback) = referencedCallbacks;
}

struct CountFieldDefaults {
  count @0 :UInt32 = 7;
  label @1 :Text = "counted";
}

struct ExpectedFieldDefaults {
  expected @0 :Text = "expected";
  items @1 :List(UInt16) = [1, 2];
}

struct IndexFieldDefaults {
  index @0 :UInt32 = 9;
  items @1 :List(Text) = ["zero", "one"];
}

struct SourceFieldDefaults {
  source @0 :Text = "source";
  items @1 :List(Text) = ["alpha", "beta"];
}

struct StartFieldDefaults {
  start @0 :Text = "start";
  items @1 :List(UInt16) = [1, 2, 3];
}

struct BuilderFieldDefaults {
  builder @0 :Text = "builder";
  items @1 :List(Text) = ["build"];
}

struct OptionsFieldDefaults {
  options @0 :Text = "options";
  item @1 :NullPointerDefaults;
}

struct LocationFieldDefaults {
  segment_id @0 :Text = "segment";
  word_index @1 :Text = "word";
  item @2 :NullPointerDefaults;
}

struct ElementSizeFieldDefaults {
  element_size @0 :Text = "element";
  any @1 :AnyPointer;
}

struct ReaderFieldDefaults {
  reader @0 :Text = "reader";
}

struct SizeFieldDefaults {
  size @0 :UInt32 = 64;
}

struct NewValueFieldDefaults {
  new_value @0 :Text = "new";
  items @1 :List(Text) = ["value"];
}

struct OrphanFieldDefaults {
  orphan @0 :Text = "orphan";
}

struct GeneratedMemberFieldDefaults {
  validate @0 :Text = "validate";
  totalSize @1 :Text = "total";
  Orphan @2 :Text = "orphan-type";
  Builder @3 :Text = "builder-type";
  fromReader @4 :Text = "from-reader";
}

interface Defaults {
  enum LocalMode {
    stopped @0;
    running @1;
  }

  using ModeAlias = LocalMode;
  const defaultLocalMode :ModeAlias = running;
  const defaultLabel :Text = "local";
  const defaultPayload :Data = 0x"0a 0b";
  const defaultMaybeVoid :?Void = void;
  const defaultMaybeFlag :?Bool = true;
  const defaultMaybeAmount :?UInt32 = 321;
  const defaultMaybeRatio :?Float64 = +3.5e1;
  const defaultMaybeMode :?ModeAlias = stopped;
  const defaultMaybeCap :?Capability = void;
  const defaultMaybeAny :?AnyPointer = null;
  const defaultMaybeAnyStruct :?AnyStruct = null;
  const defaultMaybeAnyList :?AnyList = null;
  const defaultMaybeLabel :?Text = "maybe local";
  const defaultMaybePayload :?Data = 0x"0e 0f";
  const defaultNumbers :List(UInt16) = [7, 8];
  const defaultLabels :List(Text) = ["alpha", "beta"];
  const defaultPayloads :List(Data) = [0x"0c 0d", "raw"];
  const defaultModes :List(ModeAlias) = [stopped, running];
  const defaultGroups :List(List(UInt16)) = [[1, 2], [3]];

  struct Item {
    value @0 :UInt32;
    label @1 :Text;
  }

  interface Callback {
    done @0 () -> ();
  }

  const defaultCaps :List(Capability) = [void, null];
  const defaultCallbacks :List(Callback) = [void];

  const defaultItems :List(Item) = [(value = 10, label = "ten"), (value = 20, label = "twenty")];
  const defaultItem :Item = (value = 99, label = "ninety-nine");
  const defaultMaybeItem :?Item = (value = 77, label = "seventy-seven");
  const defaultMaybeAnyItem :?AnyPointer = defaultItem;
  const defaultMaybeAnyStructItem :?AnyStruct = defaultItem;
  const defaultMaybeAnyListNumbers :?AnyList = defaultNumbers;
  const defaultMaybeNumbers :?List(UInt16) = [5, 6];
  const defaultMaybeItems :?List(Item) = [(value = 30, label = "thirty"), (value = 40, label = "forty")];
  const defaultNothing :?Item = null;

  scalars @0 (
    v :Void = void,
    b :Bool = true,
    i8 :Int8 = -8,
    i16 :Int16 = -16,
    i32 :Int32 = -32,
    i64 :Int64 = -64,
    u8 :UInt8 = 8,
    u16 :UInt16 = 16,
    u32 :UInt32 = 32,
    u64 :UInt64 = 64,
    f32 :Float32 = 1.5,
    f64 :Float64 = -2.25,
    mode :Mode = on,
    text :Text = "hi",
    data :Data = 0x"01 02"
  ) -> (resultMode :Mode = off);

  scoped @1 (
    mode :ModeAlias = defaultLocalMode,
    label :Text = defaultLabel,
    payload :Data = defaultPayload
  ) -> (resultMode :ModeAlias = defaultLocalMode);

  lists @2 (
    numbers :List(UInt16) = defaultNumbers,
    labels :List(Text) = defaultLabels,
    payloads :List(Data) = defaultPayloads,
    modes :List(ModeAlias) = defaultModes,
    groups :List(List(UInt16)) = defaultGroups,
    items :List(Item) = defaultItems
  ) -> ();

  structs @3 (item :Item = defaultItem) -> (result :Item = (value = 123, label = "result"));

  optionals @4 (
    label :?Text = defaultMaybeLabel,
    payload :?Data = defaultMaybePayload,
    numbers :?List(UInt16) = defaultMaybeNumbers,
    item :?Item = defaultMaybeItem,
    emptyLabel :?Text = null,
    any :AnyPointer = null,
    cap :Capability = void
  ) -> (result :?Item = defaultMaybeItem);

  anyDefaults @5 (
    anyStruct :AnyPointer = defaultItem,
    structValue :AnyStruct = defaultItem,
    anyList :AnyPointer = defaultNumbers,
    listValue :AnyList = defaultNumbers
  ) -> ();

  capabilityDefaults @6 (callback :Callback = void) -> ();

  capabilityLists @7 (
    caps :List(Capability) = defaultCaps,
    callbacks :List(Callback) = defaultCallbacks
  ) -> ();

  literalSyntax @8 (
    greeting :Text = "hello, method",
    payload :Data = "raw,bytes",
    marker :Text = "contains $ marker"
  ) -> (reply :Text = "ok, result");
}

const referencedItem :Defaults.Item = (value = 88, label = "referenced item");
