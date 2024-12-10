{
  __functor = _: { Tikal, nixpkgs, ... }:
  let
    inherit (Tikal.Prelude.Trivial) write-text-file;
  in
    {
      domain = _: write-text-file {
        name = "hellop";
        text = "Hello, World";
      };
    }
  ;
}
