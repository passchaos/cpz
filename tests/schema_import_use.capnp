@0xbadc0ffee000002;

using Base = import "schema_import_base.capnp";
using import "schema_import_base.capnp".Child;

struct Holder {
  child @0 :Base.Child;
  children @1 :List(Base.Child);
  shared @2 :Child;
}
