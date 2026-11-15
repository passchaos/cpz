@0xabcdef1234567890;

struct Person {
  id @0 :UInt32;
  name @1 :Text;
}

struct AddressBook {
  people @0 :List(Person);
}
