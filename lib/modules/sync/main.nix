{ lib, pkgs, sync-context, universe, newScope, tikal, ... }:
let

  /**
  This scope is the context that gets passed as argument when evaluating
  the "sync" modules. This context contains libraries specifically meant
  for generating sync scripts.
  */
  scope = lib.makeScope newScope (self: {
    inherit tikal universe lib pkgs;
    tikal-foundations = self.callPackage ../shared/tikal-foundations.nix {};
    # nahual-pkgs = nahual-pkgs self;
    tikal-store-lock = self.callPackage ../shared/tikal-store-lock.nix {};
    tikal-secrets = self.callPackage ../tikal-secrets.nix {};
    tikal-nixos-context = self.callPackage ../tikal-nixos-context.nix {};
    tikal-flake-context = self.callPackage ../tikal-flake-context.nix {};
    tikal-sync-context = sync-context.config;
  });
in
  scope
