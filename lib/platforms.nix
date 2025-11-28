{
  nixos-rockchip,
  nixpkgs,
  lib,
  system,
  pkgs,
  ...
}:
let
  platforms-scope = lib.makeScope pkgs.newScope (self: {
    inherit nixpkgs system nixos-rockchip;
    rockchip = self.callPackage ./platforms/rockchip.nix {};
  });
in
  {
    platforms = with platforms-scope;
      rockchip.platforms
    ;
  }

