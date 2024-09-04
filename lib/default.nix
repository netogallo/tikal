{
  tikal ? import ../default.nix {}
}:
let
  inherit (tikal) callPackage;
in
rec {
  prim-lib = callPackage ./prim-lib.nix {};
  prim-types = callPackage ./prim-types/default.nix {};
  base = prim-types.new-module ../tikal-base {};
}
