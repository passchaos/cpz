@0xc0ffee;

enum Color @0xc010 {
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
using GenericPersonAlias = GenericBox(Person);

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

annotation schemaNote @0xa110ca110c (file, struct, field) :Text;
annotation marker(interface, method) :Void;
annotation labels(enumerant) :List(Text);

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
  blockName @20 :Text = `block
    default
    ;
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
  metadata :group {
    created @4 :UInt64;
    label @5 :Text;
  }
  selected :union {
    text @6 :Text;
    code @7 :UInt32;
  }
  after @3 :Text;
}

struct DynamicBox @0xd00d {
  any @0 :AnyPointer;
  anyStruct @1 :AnyStruct;
  anyList @2 :AnyList;
  cap @3 :Capability;
  capList @4 :List(Capability);
  blob @5 :Data;
  anyListItems @6 :List(AnyPointer);
  anyStructItems @7 :List(AnyStruct);
  anyListList @8 :List(AnyList);
}

struct AliasBox {
  id @0 :Id = 11;
  shade @1 :Shade = blue;
  names @2 :List(Name);
  dynamic @3 :DynamicAlias;
  caps @4 :List(CapAlias);
}

struct ScopedAliasBox {
  using LocalId = Id;
  using LocalName = Name;
  using LocalNames = List(LocalName);
  using LocalShade = Shade;
  using LocalFriend = Person;
  using LocalScores = List(LocalId);

  const defaultLocalId :LocalId = 77;
  const defaultLocalNames :LocalNames = ["local", "aliases"];
  const defaultLocalScores :LocalScores = [3, 4];

  id @0 :LocalId = 21;
  name @1 :LocalName = "local";
  names @2 :LocalNames;
  shade @3 :LocalShade = red;
  friend @4 :LocalFriend;
  union {
    aliasId @5 :LocalId;
    aliasName @6 :LocalName;
  }
}

interface Service {
  call @0 () -> () $marker;
  ping @1 [Req, Resp] (request :Req, attempts :UInt32 = 3) -> (response :Resp);
  streamIt @2 (chunk :Data) -> stream;
}

interface ExtendedService @0xe57e0001(Req, Resp) extends(Service) {
  struct Details {
    message @0 :Text;
  }

  interface Callback {
    done @0 (details :Details) -> ();
  }

  using DetailsAlias = Details;
  const defaultLimit :UInt16 = 12;
  const defaultLabel :Text = "extended";
  annotation detailNote(field) :DetailsAlias;

  pong @0 () -> ();
}

struct InterfaceBox {
  service @0 :Service;
  services @1 :List(Service);
}

struct NestedBox {
  struct Item {
    value @0 :UInt32;
    label @1 :Text;
  }

  enum Status {
    unknown @0;
    ready @1;
  }

  annotation itemNote(field) :Item;
  annotation statusLabels(enumerant) :List(Status);

  item @0 :Item;
  items @1 :List(Item);
  status @2 :Status = ready;
}

struct GenericBox(T) {
  struct Inner {
    id @0 :UInt32;
    label @1 :Text;
  }

  value @0 :T;
}

struct GenericUseBox {
  direct @0 :GenericBox(Person);
  alias @1 :GenericPersonAlias;
  many @2 :List(GenericBox(Person));
  nested @3 :GenericBox(Person).Inner;
}
