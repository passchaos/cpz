@0xc0ffee;

enum Color {
  red @0;
  green @1;
  blue @2;
}

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
}

struct Choice {
  before @0 :Text;
  union {
    name @1 :Text;
    id @2 :UInt32;
  }
  after @3 :Text;
}
