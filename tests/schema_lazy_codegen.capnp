@0xd1a7c0deca75cafe;

struct Holder {
  text @0 :Text;
}

struct Groups {
  union {
    foo :group {
      id @0 :UInt32;
      label @1 :Text;
    }
    bar @2 :Void;
  }
}

struct Generic(Foo, Bar) {
  using AliasFoo = Foo;
  using AliasInner = Inner;
  using AliasInnerText = Inner(Text);
  using AliasRev = Generic(Bar, Foo);

  struct Inner(Baz) {
    foo @0 :Foo;
    bar @1 :Bar;
    baz @2 :Baz;
  }

  struct UseAliases {
    revFoo @0 :AliasRev.AliasFoo;
  }
}

struct UseConcreteAliases {
  aliasFoo @0 :Generic(Holder, Text).AliasFoo;
  aliasInner @1 :Generic(Holder, Text).AliasInnerText;
}

struct Constants {
  const structConst :Holder = (text = "one");
  const structListConst :List(Holder) = [(text = "one"), (text = "two")];
}
