enum Mode {
  off @0;
  on @1;
}

const referencedText :Text = "referenced text";
const referencedData :Data = 0x"12 34";

struct MaybeDefaults {
  absent @0 :?Text = null;
}

struct NullPointerDefaults {
  text @0 :Text = null;
  data @1 :Data = null;
  numbers @2 :List(UInt16) = null;
  item @3 :Defaults.Item = null;
}

struct ConstRefDefaults {
  const localText :Text = "local text";
  const localData :Data = 0x"56 78";

  text @0 :Text = referencedText;
  data @1 :Data = referencedData;
  localTextField @2 :Text = localText;
  localDataField @3 :Data = localData;
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

  const defaultItems :List(Item) = [(value = 10, label = "ten"), (value = 20, label = "twenty")];
  const defaultItem :Item = (value = 99, label = "ninety-nine");
  const defaultMaybeItem :?Item = (value = 77, label = "seventy-seven");
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
}
