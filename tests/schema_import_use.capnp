@0xbadc0ffee000002;

using Base = import "schema_import_base.capnp";
using import "schema_import_base.capnp";
using import "schema_import_base.capnp".Child;
using Base.Extra;

struct Holder {
  child @0 :Base.Child;
  children @1 :List(Base.Child);
  shared @2 :Child;
  extra @3 :Extra;
  extras @4 :List(Extra);
  directChild @5 :import "schema_import_base.capnp".Child;
  directChildren @6 :List(import "schema_import_base.capnp".Child);
  bareChild @7 :schema_import_base.Child;
  bareChildren @8 :List(schema_import_base.Child);
}

struct ScopedImportHolder {
  using Local = import "schema_import_base.capnp";
  using import "schema_import_base.capnp".Extra;

  child @0 :Local.Child;
  children @1 :List(Local.Child);
  extra @2 :Extra;
  extras @3 :List(Extra);
}
