{
  pkgs,
  lib,
  tikal,
  callPackage,
  tikal-crypto
}:
let
  inherit (tikal.store) secrets;
  inherit (tikal.prelude) do;
  tikal-secrets-shared = callPackage ../shared/tikal-secrets.nix {};
  inherit (tikal-secrets-shared) get-secret-key;
  inherit (tikal-crypto) nahual-master-keys;

  to-nahual-secret-derivation =
    { name, nahual, text, user ? null, group ? null, post-decrypt ? [] }:
    let
      tikal-key = nahual-master-keys.${nahual}.public-key-file;
      extra-post-decrypt = map secrets.to-post-decrypt-script post-decrypt;
    in
      secrets.to-nahual-secret {
        inherit name tikal-key text;
        post-decrypt = [
          (secrets.set-ownership { inherit user group; })
        ]
        ++ extra-post-decrypt;
      }
  ;

  to-nahual-secret = args@{ name, nahual, ... }:
    {
      derive = to-nahual-secret-derivation args;
      key = get-secret-key { inherit name nahual; };
    }
  ;

  /**
  This function is responsible for generating the tikal master
  keys for all nahuales and making the public key available
  to nix, allowing derivations to generate secrets which
  can then be ecrypted before being written to the nix
  store.

  The tikal master keys (and all other secrets) are generated
  during the `sync` phase. Afterwards they become part of the
  flake and `tikal-store-lock` module takes care of mantaining
  the catalogue. This means that the public credentials of
  the tikal master keys are only generated once and then
  are read from the tikal config directory that exists in
  the flake.
  */
  locks-all-nahuales = { nahuales, all-nahuales }:
    let
      to-all-nahuales-secret = name: args:
      let
        to-nahual-secret-config = nahual: {
          ${nahual} = to-nahual-secret (args // { inherit name; inherit nahual; });
        };
      in
        lib.map to-nahual-secret-config nahuales
      ;
    in
      do [
        all-nahuales
        "$>" lib.mapAttrs to-all-nahuales-secret
        "|>" lib.attrValues
        "|>" lib.concatLists
        "|>" lib.foldAttrs (item: acc: [item] ++ acc) []
      ]
  ;
in
  {
    inherit locks-all-nahuales;
  }
