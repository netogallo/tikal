{ config, pkgs, lib, tikal, tikal-crypto, ... }:
let
  inherit (tikal) crypto;
  tikal-crypto-cli = crypto.tikal-crypto-cli { inherit (config.tikal.context.sync) nix-crypto-store; };
  inherit (lib) types mkOption;
  nahual-master-key-type = types.submodule {
    options = {
      public-key = mkOption {
        type = types.str;
        description = ''
          The public key corresponding to the master key belonging
          to each of the nahuales in pem format.
        '';
      };
      private-key-enc = mkOption {
        type = types.str;
        description = ''
          The private key corresponding to the public-key, encrypted
          such that it is safe to store in the nix store.
        '';
      };
      passphrase-export = mkOption {
        type = types.package;
        description = ''
          A script which allows exporting the passphrase used to
          generate the encrypted private key to an arbitrary
          location.
        '';
      };
    };
  };
  to-nahual-master-key = nahual: keys:
  let
    /*
    Expose the corresponding private key encrypted
    using a symmetric securely stored in the
    credential store. This is safe to write into
    the nix store if desired.
    */
    private-key-enc = keys.private-key-enc;
    /*
    Expose a script that can be run during the sync
    stage which writes the passphase used to encrypt the
    private key into a desired location. This is safe to
    include in the nix store as the program is useless
    unless the credential store is accesible in the directory
    where the script is run.
    */
    passphrase-export =
      pkgs.writeShellApplication {
        name = "passphrase-export";
        text = ''
          ${tikal-crypto-cli}/bin/tikal-crypto-cli export secret \
            --identity-type openssl-symmetric-key \
            --openssl-symmetric-key-id "${private-key-enc.key-id}" \
            --openssl-symmetric-key-derivation pbkdf2 \
            --openssl-symmetric-key-iterations 600000 \
            --output-file "$1"
          ''
        ;
      }
    ;
  in
    {
      /*
      Expose the public key of the nahual as a PEM
      string. This can be used by other nixos modules
      to encrypt data.
      */
      public-key = keys.public-key;
      private-key-enc = private-key-enc.ciphertext-base64;

      inherit passphrase-export;
    }
  ;
in
  {
    options = {
      tikal.sync.identities = {
        nahual-master-keys = mkOption {
          type = types.attrsOf nahual-master-key-type;
          readOnly = true;
          description = ''
            This attribute provides a list of the master cryptographic keys
            that the nahuales will use as identity and to store secrets
            in the nix store.
          '';
          default = lib.mapAttrs to-nahual-master-key tikal-crypto.nahual-master-keys;
        };
      };
    };
  }
