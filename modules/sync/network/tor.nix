{ lib, ... }:
let
  inherit (lib) mkIf;
in
  {
    imports = [ ../../shared/network/tor.nix ];
  }
