{ nixos-rockchip, build-system, ... }:
let
  platform-callPackage = name: path:
    import path { inherit nixos-rockchip build-system; }
  ;
in
  builtins.mapAttrs platform-callPackage {
    rockchip = ./tikal-platforms/rockchip.nix;
  }


