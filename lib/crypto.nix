{
  nix-crypto-flake,
  pkgs,
  tikal-config,
  lib,
  ...
}:
let
  nix-crypto-scope = lib.makeScope pkgs.newScope (self: {
    lib = self.callPackage ./cyrpto/default.nix {};
    nix-crypto-lib = self.callPackage "${nix-crypto-flake}/crypto/default.nix" {};
  });
  enabled = nix-crypto-flake != null;
  nix-crypto-pkg = nix-crypto-flake.packages.${pkgs.stdenv.system}.nix-crypto;
  nix-crypto-tikal =
    pkgs.writeShellScriptBin
    "nix"
    ''
      STORE="$PWD/${tikal-config.base-dir}/.tikal/private/nix-crypto-store"
      mkdir -p "$STORE"
      ${nix-crypto-pkg}/bin/nix \
        --option extra-cryptonix-args "mode=filesystem&store-path=$STORE" \
        "$@"
    ''
  ;
in
  if enabled
  then {
    inherit (nix-crypto-scope) lib;
    packages = {
      inherit nix-crypto-tikal;
    };
  }
  else throw ''
    The module "tikal.crypto" can only be used when running
    nix with the 'nix-crypto' plugin.
  ''
