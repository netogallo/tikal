{
  nix-crypto-flake,
  pkgs,
  tikal-config,
  lib,
  newScope,
  ...
}:
let
  nix-crypto-scope = lib.makeScope newScope (self: {
    # lib = { universe }: self.callPackage ./crypto/default.nix { inherit universe; };
    nix-crypto-lib = self.callPackage "${nix-crypto-flake}/crypto/default.nix" {};
  });
  enabled = lib.hasAttr "crypto" builtins;
  inherit (nix-crypto-flake.packages.${pkgs.stdenv.system}) nix-crypto nix-crypto-service;
  nix-crypto-tikal = { nix-crypto-store }:
    pkgs.writeShellScriptBin
    "nix"
    ''
      STORE="${nix-crypto-store}"
      mkdir -p "$STORE"
      ${nix-crypto}/bin/nix \
        --option extra-cryptonix-args "mode=filesystem&store-path=$STORE" \
        "$@"
    ''
  ;
  tikal-crypto-cli = { nix-crypto-store }:
    pkgs.writeShellScriptBin
    "tikal-crypto-cli"
    ''
    ${nix-crypto-service}/bin/nix-crypto-service --sled-store="${nix-crypto-store}" "$@"
    ''
  ;
  lib-when-enabled = attrs:
    let
      when-enabled = name: fn:
        if enabled
        then fn
        else 
          throw ''
          The module "tikal.crypto" can only be used when running
          nix with the 'nix-crypto' plugin.
          ''
      ;
    in
      lib.mapAttrs when-enabled attrs // { inherit enabled; }
  ;
in
  lib-when-enabled {
    inherit (nix-crypto-scope) nix-crypto-lib;
  } //
  {
    inherit nix-crypto-tikal tikal-crypto-cli;
  }
