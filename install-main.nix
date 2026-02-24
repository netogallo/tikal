/**
This module is responsible for generating packages which produce
images with installation media. For every platform supported by
Tikal, it will generate an installation media for each fo the
nahuales defined in the universe.
*/
{
  pkgs,
  nixos-rockchip,
  universe,
  lib,
  nixpkgs,
  ...
}@inputs:
let
  scopes = import ./tikal-scope.nix inputs;
  inherit (scopes) universe-scope;
  inherit (universe-scope) tikal lib;
  log = tikal.prelude.log.add-context { file = ./nixos-main.nix; };
  universe-module = log.log-value "install-universe" universe-scope.universe;
  full-scope = scopes.full-scope { inherit nixos-rockchip pkgs; };
  installers = full-scope.callPackage ./lib/installer.nix { inherit nixos-rockchip; };
in
  {
    packages = installers.packages;
  }
