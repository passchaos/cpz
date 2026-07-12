enum error {
  test @0;
  ok @1;
}

struct fn {
  error @0 :UInt32 = 5;
  enum @1 :error = test;
}

struct type {
  null @0 :UInt32 = 1;
  true @1 :Text = "yes";
}
