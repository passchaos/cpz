@0xbadc0ffee000002;

using Base = import "schema_import_base.capnp";
using import "schema_import_base.capnp".Child;
using Base.Extra;

struct Holder {
  child @0 :Base.Child;
  children @1 :List(Base.Child);
  shared @2 :Child;
  extra @3 :Extra;
  extras @4 :List(Extra);
}
