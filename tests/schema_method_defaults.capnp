enum Mode {
  off @0;
  on @1;
}

interface Defaults {
  scalars @0 (
    v :Void = void,
    b :Bool = true,
    i8 :Int8 = -8,
    i16 :Int16 = -16,
    i32 :Int32 = -32,
    i64 :Int64 = -64,
    u8 :UInt8 = 8,
    u16 :UInt16 = 16,
    u32 :UInt32 = 32,
    u64 :UInt64 = 64,
    f32 :Float32 = 1.5,
    f64 :Float64 = -2.25,
    mode :Mode = on,
    text :Text = "hi",
    data :Data = 0x"01 02"
  ) -> (resultMode :Mode = off);
}
