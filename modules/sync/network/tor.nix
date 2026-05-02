{ ... }:
let
  imports = [ ../../shared/network/tor.nix ];
in
  {
    inherit imports;
  }
