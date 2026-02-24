{
  nixpkgs,
  lib,
  universe,
  nixos-rockchip,
  ...
}@inputs:
let
  scopes = import ./tikal-scope.nix inputs;
  inherit (scopes) universe-scope;
  inherit (universe-scope) tikal lib;
  log = tikal.prelude.log.add-context { file = ./nixos-main.nix; };
  universe-module = log.log-value "sync-universe" universe-scope.universe;

  top-module = nahual: _: { pkgs, ... }:
    let
      full-scope = scopes.full-scope {
        inherit nixos-rockchip pkgs;
      };
      nixos-scope = full-scope.overrideScope (self: super: {
        inherit nahual;
        args = self.callPackage ./lib/modules/nixos/main.nix {};
      });
    in
      {
        imports = [ ./modules/nixos/main.nix ];
        config._module.args = {
          # Todo: if the whole "nixos-scope.args" is used. It
          # results in infinite recursion
          inherit (nixos-scope.args)
          tikal-foundations tikal-secrets tikal-store-lock tikal-nixos
          tikal universe nahual tikal-nixos-context tikal-flake-context;
        };
      }
  ;
  nixosModules = lib.mapAttrs top-module universe-module.config.nahuales;
in
  {
    inherit nixosModules;
    vms = { pkgs, ... }:
      let
        full-scope = scopes.full-scope { inherit pkgs nixos-rockchip; };
      in
        full-scope.callPackage ./lib/vms.nix { nixos-modules = nixosModules; }
    ;
  }
