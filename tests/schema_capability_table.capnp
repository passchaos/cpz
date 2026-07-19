interface Service {
  ping @0 () -> ();
}

struct CapabilityTableBox {
  cap @0 :Capability;
  maybeCap @1 :?Capability;
  caps @2 :List(Capability);
  maybeCaps @3 :List(?Capability);
  service @4 :Service;
  services @5 :List(Service);
  maybeServices @6 :List(?Service);
}
