/**
unlock.nix is responsible for making the tikal main private key available to the
nahual upon boot. In tikal, every nahual has a main public/private key pair
associated to it. The main purpose of this key pair is to encrypt secrets
before saving them to the nix store (similar to what agenix is doing). Hoever,
the private key must be made availabe to the nahual upon boot as storing this
key in the store would defeat the entire purpose.

Currently, the following methods are supported to make the private key available:
* Symmetric decryption upon boot: The private key will be encrypted using symmetric
  cryptography with a secure key. The encrypted file will be available in the
  nix store. Upon boot, the nahual will request the decryption key which will
  be then used to decrypt the private key and make it availabe at a specific
  (ephemeral) location.
*/
{ pkgs, config, nahual, lib, tikal, tikal-flake-context, tikal-foundations, tikal-nixos, ... }:
let
  inherit (tikal) hardcoded;
  inherit (tikal.template) template;
  inherit (config.tikal.meta.nixos-context) tikal-user tikal-group;
  inherit (tikal-nixos) get-public-file;
  inherit (tikal-flake-context.nahuales.${nahual}.public) tikal-keys;
  log = tikal.prelude.log.add-context { file = ./tikal-core.nix; inherit nahual; };
  tikal-paths = tikal-foundations.paths;
  tikal-main-pub =
    get-public-file {
      path = tikal-keys.tikal_main_pub;
      user = tikal-user;
      group = tikal-group;
    }
  ;
  tikal-main-enc =
    get-public-file {
      path = tikal-keys.tikal_main_enc;
      mode = 600;
      user = tikal-user;
      group = tikal-group;
  };
  /**
  unlock-script is a shell script executed on boot (oon the post device comands
  of the initrd stage) which will attempt to decrypt the tikal main key from
  the nix store.
  */
  unlock-script =
    pkgs.writeScript
    "unlock"
    (
      template
      ./unlock.sh
      {
        inherit tikal-main-enc tikal-paths;
        age = "${pkgs.age}/bin/age";
        expect = "${pkgs.expect}/bin/expect";
        inherit (hardcoded) tikal-decrypt-keys-directory tikal-decrypt-master-key-file;
      }
    )
  ;
in
  {
    config = {
      environment.etc = log.log-value "secret keys" {
        ${tikal-paths.relative.tikal-main-pub} = tikal-main-pub;
        ${tikal-paths.relative.tikal-main-enc} = tikal-main-enc;
      };

      boot.initrd = {
        postDeviceCommands = lib.mkAfter ''
          source ${unlock-script}
        '';
        extraFiles = {
          #tikal-main-pub = tikal-main-pub;
          #tikal-main-enc = tikal-main-enc;
        };
      };
    };
  }

