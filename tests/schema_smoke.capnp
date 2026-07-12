@0xc0ffee;

enum Color {
  red @0;
  green @1;
  blue @2;
}

using Id = UInt32;
using Name = Text;
using Names = TextList;
using Shade = Color;
using DynamicAlias = AnyPointer;
using CapAlias = Capability;

const globalId :UInt32 = 12345;
const globalActive :Bool = true;
const globalName :Text = "const text";
const globalPayload :Data = 0x"de ad be ef";
const globalShade :Color = blue;
const globalRatio :Float64 = +1.25e2;
const globalScores :List(UInt32) = [10, 20, 30];
const globalNames :TextList = ["alpha", "beta"];
const globalNamesAlias :Names = ["gamma", "delta"];
const globalShades :List(Color) = [red, blue];

struct Person {
  id @0 :UInt32 = 42;
  active @1 :Bool = true;
  name @2 :Text;
  favorite @3 :Color = Color.green;
  scores @4 :List(UInt32);
  children @5 :List(Person);
  friend @6 :Person;
  palette @7 :List(Color);
  nickname @8 :Text = "anon";
  aliases @9 :TextList;
  payloads @10 :DataList;
  flags @11 :BoolList;
  ratios @12 :Float32List;
  weights @13 :Float64List;
  maybeName @14 :?Text;
  maybeFriend @15 :?Person;
  scoreGroups @16 :List(List(UInt32));
  aliasGroups @17 :List(TextList);
  structGroups @18 :List(List(Person));
  marks @19 :VoidList;

  const defaultAge :UInt16 = 99;
  const defaultAlias :Text = "nested const";
  const defaultColor :Color = red;
  const defaultScores :List(UInt16) = [7, 8, 9];
}

struct Choice {
  before @0 :Text;
  union {
    name @1 :Text;
    id @2 :UInt32;
  }
  after @3 :Text;
}

struct DynamicBox {
  any @0 :AnyPointer;
  anyStruct @1 :AnyStruct;
  anyList @2 :AnyList;
  cap @3 :Capability;
  capList @4 :List(Capability);
}

struct AliasBox {
  id @0 :Id = 11;
  shade @1 :Shade = blue;
  names @2 :List(Name);
  dynamic @3 :DynamicAlias;
  caps @4 :List(CapAlias);
}

interface Service {
  call @0 () -> ();
}

struct InterfaceBox {
  service @0 :Service;
  services @1 :List(Service);
}
