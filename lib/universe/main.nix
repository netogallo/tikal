# This module processes the universe spec and produces the final universe
# module. It first supplies context used by the universe, mostly containing
# definitions and paths, and evaluates the module with said context.
# The resulting module will contain the modules which will be used to produce
# the nixos configurations for the nahuales in the universe and the modules
# which will be used to produce the sync script.
{ nixpkgs, universe, lib, tikal, newScope, tikal-config, ... }:
let
  log = tikal.prelude.log.add-context { file = ./main.nix; };
  scope = lib.makeScope newScope (self: {
    inherit nixpkgs tikal-config lib;
    tikal = {
      prelude = self.callPackage ./lib/prelude.nix {};
      hardcoded = self.callPackage ./lib/hardcoded.nix {};
    };
    universe-eval-context =
      log.log-function-call "universe-eval-context" self.callPackage ../modules/universe/main.nix { };
    shared-context =
      log.log-function-call "shared-context" self.callPackage ./shared-context.nix { };
    flake-context =
      log.log-function-call "flake-context" self.callPackage ./flake-context.nix {};

    sync-context =
      log.log-function-call "sync-context" self.callPackage ./sync-context.nix { };

    universe-module = log.log-value "universe-module" (lib.evalModules {
      modules = [
        universe
        ../../modules/universe/main.nix
      ];
      args = self.universe-eval-context;
    });
  });
in
  scope.universe-module
