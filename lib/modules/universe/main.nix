{ flake-context, sync-context, tikal, lib, newScope, ... }:
let
  log = tikal.prelude.log.add-context { file = ./main.nix; };

  /**
  This is the scope that gets passed as the arguments to the modules
  which define the universe. This module mainly contains libraries
  which are specific to the universe evaluation stage.
  */
  scope = lib.makeScope newScope (self: {
    inherit tikal;
    tikal-foundations = self.callPackage ../shared/tikal-foundations.nix {};
    tikal-log = self.callPackage ../shared/tikal-log.nix {};
    tikal-nixos-context = self.callPackage ../tikal-nixos-context.nix {};
    tikal-flake-context = self.callPackage ../tikal-flake-context.nix {};
    tikal-sync-context = sync-context.config;
  });
in
  scope
