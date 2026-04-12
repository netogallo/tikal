{
  pkgs,
  lib,
  callPackage
}:
let
  tikal-secrets-shared = callPackage ../shared/tikal-secrets.nix {};
  inherit (tikal-secrets-shared) secrets-activation-script get-secret-key
    get-secret-public-path get-secret-private-path;
  get-activation-scripts = { nahual, all-nahuales }:
    let
      keys-from-secret = name: get-secret-key { inherit name nahual; };
      keys = lib.map keys-from-secret (lib.attrNames all-nahuales);
    in
      secrets-activation-script keys
  ;
in
  {
    inherit get-activation-scripts get-secret-public-path
      get-secret-private-path;
  }
