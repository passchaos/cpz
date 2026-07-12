enum error {
  test @0;
  ok @1;
}

struct fn {
  error @0 :UInt32 = 5;
  enum @1 :error = test;
}
