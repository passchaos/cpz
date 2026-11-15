@0xc0de0f00;

struct Item {
  id @0 :UInt32;
  name @1 :Text;
}

struct Root {
  item @0 :Item;
  items @1 :List(Item);
  scores @2 :List(UInt32);
}
