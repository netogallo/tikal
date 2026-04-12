{
  pkgs,
  lib,
  universe,
  tikal,
  ...
}:
let
  inherit (tikal.crypto) nix-crypto-lib;
  inherit (nix-crypto-lib) openssl;
  pk-rsa = openssl.private-key { 
    attrs = {
      vault = "tikal/${universe.config.universe.id}";
      name = "openssl-test-key";
    };
    type = "rsa";
  };
  vault = "tikal/${universe.config.universe.id}";
  serial = "1";
  get-tikal-master-key = { nahual }:
  let
    identity-attrs = {
      inherit serial vault nahual;
      role = "nahual-master-key";
    };

    identity = {
      attrs = identity-attrs;
      type = "rsa";
    };

    pkey = openssl.private-key identity;

    symmetric-key-identity = {
      attrs = identity-attrs;
      key-derivation = "pbkdf2";
      iterations = 600000;
    };
  in
    {
      public-key = pkey.public-key-pem;
      public-key-file = pkgs.writeText "${nahual}-public" pkey.public-key-pem; 
      private-key-enc = pkey.export-decryptable-pkey symmetric-key-identity;
    }
  ;
  nahual-master-keys =
    lib.mapAttrs
    (nahual: _: get-tikal-master-key { inherit nahual; })
    universe.config.nahuales
  ;
in
  {
    inherit nahual-master-keys;
  }
