{
  newScope,
  tikal,
  universe,
  lib,
  pkgs,
  platform-name,
  platform-spec,
  nixos-rockchip,
  ...
}:
let
  log = tikal.prelude.log.add-context { file = ./main-installer.nix; };
in
  log.log-function-call "scope" lib.makeScope newScope (self: {
    inherit lib pkgs platform-name platform-spec tikal nixos-rockchip;
    tikal-installer = self.callPackage ./tikal-installer.nix {};
    #tikal-platforms = self.callPackage ./tikal-platforms.nix {};
    tikal-flake-context = self.callPackage ../tikal-flake-context.nix {};
  })
