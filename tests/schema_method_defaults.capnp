enum Mode {
  off @0;
  on @1;
}

const referencedText :Text = "referenced text";
const referencedTextAlias :Text = referencedText;
const referencedData :Data = 0x"12 34";
const referencedDataAlias :Data = referencedData;
const referencedNullText :Text = null;
const referencedNullData :Data = null;
const referencedFlag :Bool = true;
const referencedAmount :UInt32 = 123;
const referencedAmountAlias :UInt32 = referencedAmount;
const referencedRatio :Float64 = +1.25e2;
const referencedMode :Mode = on;
const referencedModeAlias :Mode = referencedMode;
const referencedNumbers :List(UInt16) = [7, 8];
const referencedNumbersAlias :List(UInt16) = referencedNumbers;
const referencedNullNumbers :List(UInt16) = null;
const referencedCap :Capability = void;
const referencedCallback :TopCallback = void;
const referencedAny :AnyPointer = null;
const referencedAnyStruct :AnyStruct = null;
const referencedAnyList :AnyList = null;
const referencedCaps :List(Capability) = [void, null];
const referencedCallbacks :List(TopCallback) = [void];
const referencedMaybeCallback :?TopCallback = void;
const referencedNullItem :Defaults.Item = null;
const referencedAnyItem :AnyPointer = referencedItem;
const referencedAnyStructItem :AnyStruct = referencedItem;
const referencedAnyListNumbers :AnyList = referencedNumbers;
const referencedItemAlias :Defaults.Item = referencedItem;

interface TopCallback {
  ping @0 () -> ();
}

using MaybeCallbacks = List(?TopCallback);
using DefaultsAlias = Defaults;
using ConstRefAlias = ConstRefDefaults;

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
  labels @0 :List(?Text) = ["field label", null, referencedText];
  payloads @1 :List(?Data) = [0x"aa bb", null, referencedData];
  caps @2 :List(?Capability) = [void, null];
  anyValues @3 :List(?AnyPointer) = [referencedItem, null, referencedNumbers];
  anyStructs @4 :List(?AnyStruct) = [referencedItem, null];
  anyLists @5 :List(?AnyList) = [referencedNumbers, null];
  callbacks @6 :List(?TopCallback) = [void, null];
  items @7 :List(?Defaults.Item) = [referencedItem, null];
}

struct AnyListDefaults {
  anyValues @0 :List(AnyPointer) = [referencedItem, referencedNumbers];
  structValues @1 :List(AnyStruct) = [referencedItem];
  listValues @2 :List(AnyList) = [referencedNumbers];
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
  using LocalDefaultsAlias = DefaultsAlias;

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
  interfaceText @20 :Text = Defaults.defaultLabel;
  interfaceData @21 :Data = Defaults.defaultPayload;
  interfaceNumbers @22 :List(UInt16) = Defaults.defaultNumbers;
  interfaceMode @23 :Defaults.LocalMode = Defaults.defaultLocalMode;
  interfaceTextViaAlias @24 :Text = DefaultsAlias.defaultLabel;
  localInterfaceTextViaAlias @25 :Text = LocalDefaultsAlias.defaultLabel;
  interfaceModeViaAlias @26 :Defaults.LocalMode = DefaultsAlias.defaultLocalMode;
  chainedText @27 :Text = referencedTextAlias;
  chainedData @28 :Data = referencedDataAlias;
  chainedAmount @29 :UInt32 = referencedAmountAlias;
  chainedMode @30 :Mode = referencedModeAlias;
  anyFromConst @31 :AnyPointer = referencedAnyItem;
  anyStructFromConst @32 :AnyStruct = referencedAnyStructItem;
  anyListFromConst @33 :AnyList = referencedAnyListNumbers;
  ownerChainedText @34 :Text = Defaults.defaultLabelAlias;
  ownerChainedData @35 :Data = Defaults.defaultPayloadAlias;
  ownerChainedMode @36 :Defaults.LocalMode = Defaults.defaultLocalModeAlias;
  ownerChainedNumbers @37 :List(UInt16) = Defaults.defaultNumbersAlias;
}

struct StructOwnerAliasDefaults {
  text @0 :Text = ConstRefAlias.localText;
  amount @1 :UInt32 = ConstRefAlias.localAmount;
  mode @2 :Mode = ConstRefAlias.localMode;
  numbers @3 :List(UInt16) = ConstRefAlias.localNumbers;
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
  const defaultLocalModeAlias :ModeAlias = defaultLocalMode;
  const defaultLabel :Text = "local";
  const defaultLabelAlias :Text = defaultLabel;
  const defaultPayload :Data = 0x"0a 0b";
  const defaultPayloadAlias :Data = defaultPayload;
  const defaultNullLabel :Text = null;
  const defaultNullPayload :Data = null;
  const defaultMaybeNullLabelRef :?Text = defaultNullLabel;
  const defaultMaybeNullPayloadRef :?Data = defaultNullPayload;
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
  const defaultMaybeReferencedText :?Text = referencedText;
  const defaultMaybeReferencedData :?Data = referencedData;
  const defaultNumbers :List(UInt16) = [7, 8];
  const defaultNumbersAlias :List(UInt16) = defaultNumbers;
  const defaultNullNumbers :List(UInt16) = null;
  const defaultLabels :List(Text) = ["alpha", "beta"];
  const defaultPayloads :List(Data) = [0x"0c 0d", "raw"];
  const defaultModes :List(ModeAlias) = [stopped, running];
  const defaultGroups :List(List(UInt16)) = [[1, 2], [3]];
  const defaultMaybeLabels :List(?Text) = ["maybe alpha", null, defaultMaybeLabel, referencedText];
  const defaultMaybePayloads :List(?Data) = [0x"aa bb", null, defaultMaybePayload, referencedData];
  const defaultMaybeFlags :List(?Bool) = [true, null, referencedFlag];
  const defaultMaybeAmounts :List(?UInt32) = [1, null, defaultMaybeAmount, referencedAmount];
  const defaultMaybeRatios :List(?Float64) = [+1.5, null, defaultMaybeRatio, referencedRatio];
  const defaultMaybeModes :List(?ModeAlias) = [running, null, defaultMaybeMode, defaultLocalMode];

  struct Item {
    value @0 :UInt32;
    label @1 :Text;
  }

  interface Callback {
    done @0 () -> ();
  }

  const defaultCap :Capability = void;
  const defaultCallback :Callback = void;
  const defaultAnyNull :AnyPointer = null;
  const defaultAnyStructNull :AnyStruct = null;
  const defaultAnyListNull :AnyList = null;
  const defaultCaps :List(Capability) = [void, null];
  const defaultCallbacks :List(Callback) = [void];
  const defaultMaybeCapElements :List(?Capability) = [void, null];
  const defaultMaybeCallbackElements :List(?Callback) = [void, null];

  const defaultItems :List(Item) = [(value = 10, label = "ten"), (value = 20, label = "twenty")];
  const defaultMaybeItemElements :List(?Item) = [defaultMaybeItem, null, defaultItem];
  const defaultItem :Item = (value = 99, label = "ninety-nine");
  const defaultItemAlias :Item = defaultItem;
  const defaultMaybeItem :?Item = (value = 77, label = "seventy-seven");
  const defaultMaybeAnyItem :?AnyPointer = defaultItem;
  const defaultMaybeAnyStructItem :?AnyStruct = defaultItem;
  const defaultMaybeAnyListNumbers :?AnyList = defaultNumbers;
  const defaultMaybeAnyValues :List(?AnyPointer) = [defaultMaybeItem, null, defaultMaybeNumbers];
  const defaultMaybeAnyStructs :List(?AnyStruct) = [defaultMaybeItem, null];
  const defaultMaybeAnyLists :List(?AnyList) = [defaultMaybeNumbers, null];
  const defaultAnyValues :List(AnyPointer) = [defaultItem, defaultNumbers];
  const defaultAnyStructs :List(AnyStruct) = [defaultItem];
  const defaultAnyLists :List(AnyList) = [defaultNumbers];
  const defaultAnyItem :AnyPointer = defaultItem;
  const defaultAnyStructItem :AnyStruct = defaultItem;
  const defaultAnyListNumbers :AnyList = defaultNumbers;
  const defaultMaybeLabelsNull :?List(?Text) = null;
  const defaultMaybePayloadsNull :?List(?Data) = null;
  const defaultMaybeCallbacksNull :?List(?Callback) = null;
  const defaultMaybeItemsNull :?List(?Item) = null;
  const defaultMaybeNumbers :?List(UInt16) = [5, 6];
  const defaultMaybeNumbersRef :?List(UInt16) = defaultNumbers;
  const defaultMaybeItems :?List(Item) = [(value = 30, label = "thirty"), (value = 40, label = "forty")];
  const defaultMaybeItemsRef :?List(Item) = defaultItems;
  const defaultMaybeCaps :?List(Capability) = defaultCaps;
  const defaultMaybeCallbacks :?List(Callback) = defaultCallbacks;
  const defaultNullItem :Item = null;
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
    caps :?List(Capability) = defaultMaybeCaps,
    callbacks :?List(Callback) = defaultMaybeCallbacks,
    item :?Item = defaultMaybeItem,
    emptyLabel :?Text = null,
    any :AnyPointer = null,
    cap :Capability = void
  ) -> (result :?Item = defaultMaybeItem);

  anyDefaults @5 (
    anyStruct :AnyPointer = defaultItem,
    structValue :AnyStruct = defaultItem,
    anyList :AnyPointer = defaultNumbers,
    listValue :AnyList = defaultNumbers,
    anyValues :List(AnyPointer) = [defaultItem, defaultNumbers],
    structValues :List(AnyStruct) = [defaultItem],
    listValues :List(AnyList) = [defaultNumbers]
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

  optionalAnyRefs @9 (
    any :AnyPointer = defaultMaybeItem,
    structValue :AnyStruct = defaultMaybeItem,
    anyList :AnyPointer = defaultMaybeNumbers,
    listValue :AnyList = defaultMaybeNumbers
  ) -> ();

  optionalElementLists @10 (
    labels :List(?Text) = ["alpha", null, defaultMaybeLabel],
    payloads :List(?Data) = [0x"0a 0b", null, defaultMaybePayload],
    items :List(?Item) = [(value = 11, label = "eleven"), null, defaultMaybeItem],
    anyValues :List(?AnyPointer) = [defaultMaybeItem, null, defaultMaybeNumbers],
    anyStructs :List(?AnyStruct) = [defaultMaybeItem, null],
    anyLists :List(?AnyList) = [defaultMaybeNumbers, null],
    caps :List(?Capability) = [void, null],
    callbacks :List(?Callback) = [void]
  ) -> ();
}

const referencedItem :Defaults.Item = (value = 88, label = "referenced item");
