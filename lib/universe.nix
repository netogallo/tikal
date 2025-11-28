{ universe, lib, flake-root, base-dir, callPackage, tikal, pkgs, ... }:
let
  log = tikal.prelude.log.add-context { file = ./universe.nix; };
  universe-eval-scope =
    lib.makeScope pkgs.newScope (self: {
      inherit tikal lib pkgs flake-root base-dir universe;
      universe-eval-context = self.callPackage ./modules/universe/main.nix { };
      shared-context = self.callPackage ./universe/shared-context.nix {};
      flake-context = self.callPackage ./universe/flake-context.nix {};
    })
  ;
  inherit (universe-eval-scope) universe-eval-context flake-context;
  module = log.log-value "universe-module.module" (lib.evalModules {
    modules = [
      ../modules/tikal-main.nix
      universe
    ];
    args = universe-eval-context;
  });

  sync-scope =
    lib.makeScope pkgs.newScope (self: {
      inherit lib base-dir pkgs;
      universe-module = module;
      shared-context = self.callPackage ./universe/shared-context.nix {};
      sync-context = self.callPackage ./universe/sync-context.nix {};
    })
  ;
  
  universe-module = log.log-value "universe-module" {
    inherit module;
    # inherit (sync-scope.sync-context) sync-scripts;
  };
in
  {
    # Config is meant to be a static representation of
    # the nixos universe. Its main objective is to be json
    # serializable so it can be embeded into sync scripts
    config = log.log-value "sync config" sync-scope.sync-context.config;
    # Set which contains the universe module along
    # with functions and attribtues to derive attributes
    # from the module
    inherit universe-module;

    # flake contains all the attributes that are to be used
    # by the flake when building the set of nahuales after
    # sync has been run.
    flake = flake-context.override { nahuales = module.config.nahuales; };
  }
