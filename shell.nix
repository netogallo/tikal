{
  tikal ? import ./default.nix {}
}:
let
  inherit (tikal) nixpkgs utils;
  inherit (nixpkgs) mkShellNoCC;
in
{
  tikal-vnc = tikal.callPackage ./utils/tikal-vnc.shell.nix {};
}
