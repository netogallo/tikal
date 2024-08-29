{
  tikal ? import ./default.nix {}
}:
let
  inherit (tikal) nixpkgs utils;
  inherit (nixpkgs) mkShellNoCC;
in
{
  tikal-vnc = mkShellNoCC {
    name = "tikal-vnc-shell";
    buildInputs = [ utils.tikal-vnc ];
  };
}
