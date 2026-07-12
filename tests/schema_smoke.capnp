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
  favorite @3 :Color = green;
}
