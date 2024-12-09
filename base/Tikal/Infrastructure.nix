{
  __functor = _: { Tikal, ... }:
  let
    inherit (Tikal.Prelude.Trivial) write-text-file;
  in
    {
      domain = _: write-text-file {
        name = "hello";
        text = "Hello, World";
      };
    }
  ;
}
