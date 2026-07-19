@0xabcabcabcabcabcd;

enum Tone {
  low @0;
  high @1;
}

struct Child {
  id @0 :UInt32;
}

struct Demo {
  tone @0 :Tone = high;
  child @1 :Child;
}

const defaultTone :Tone = low;
