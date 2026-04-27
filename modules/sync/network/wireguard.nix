{ ... }:
let
  imports = [ ../shared/network/wireguard.nix ];
in
  {
    inherit imports;
  }
