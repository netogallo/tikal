{
  tikal ? import ../default.nix {}
}:
let
  inherit (tikal) callPackage;
  core = callPackage ./types/core.nix {};
in
{
  inherit core;

  String = core.new-type "String" {
    module = "Tikal.Nix.Types";

    __prim = ''
      { lib, result, ... }: {
        new = prim:
          if lib.isType "string" prim
          then result.value prim
          else result.error "Expected a lambda"
        ;
      }
    '';

    members = { self-type }: {

    };
  };
}
