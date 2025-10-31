{ lib, tikal, flake-context, callPackage, ... }:
let
  inherit (tikal.store) lock;
  inherit (tikal.store.lock) hash-key;
  shared = callPackage ../shared/tikal-store-lock.nix {};
  lockdir-root = flake-context.public-dir;
  get-resource-path =
    lib.makeOverridable
    lock.get-resource-path
    { inherit lockdir-root; }
  ;
  universe = {
    inherit get-resource-path;
  };
in
  shared //
  {
    inherit universe;
  }
