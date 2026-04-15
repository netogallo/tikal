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
      to-secret = name: secret: {
        key = { inherit name nahual; };
        inherit secret;
      };

      secrets = lib.mapAttrs to-secret all-nahuales;
    in
      secrets-activation-script (lib.attrValues secrets)
  ;
in
  {
    inherit get-activation-scripts get-secret-public-path
      get-secret-private-path;
  }
