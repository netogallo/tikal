{
  nix-crypto-flake,
  pkgs,
  tikal-config,
  lib,
  newScope,
  sync-module,
  ...
}:
let
  nix-crypto-scope = lib.makeScope newScope (self: {
    lib = self.callPackage ./crypto/default.nix {};
    nix-crypto-lib = self.callPackage "${nix-crypto-flake}/crypto/default.nix" {};
  });
  enabled = nix-crypto-flake != null;
  nix-crypto-pkg = nix-crypto-flake.packages.${pkgs.stdenv.system}.nix-crypto;
  nix-crypto-tikal =
    pkgs.writeShellScriptBin
    "nix"
    ''
      STORE="${sync-module.config.tikal.context.sync.nix-crypto-store}"
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
