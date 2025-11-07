{ lib, tikal, flake-context, callPackage, ... }:
let
  inherit (tikal.store) lock;
  inherit (tikal.store.lock) hash-key;
  shared = callPackage ../shared/tikal-store-lock.nix {};
  lockdir-root = flake-context.public-dir;
  with-context = fn: lib.makeOverridable fn { inherit lockdir-root; };
  universe = with lock; lib.mapAttrs (key: with-context) {
    inherit get-resource-path get-resource-name;
  };
in
  shared //
  {
    inherit universe;
  }
