{
  tikal ? import ../default.nix {}
}:
let
  inherit (tikal) callPackage;
in
{
  prim-lib = callPackage ./prim-lib.nix {};
  types = callPackage ./types.nix {};
}
