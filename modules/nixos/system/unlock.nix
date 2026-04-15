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
{
  pkgs,
  config,
  nahual,
  lib,
  tikal,
  tikal-flake-context,
  tikal-foundations,
  tikal-nixos,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (tikal.prelude) path;
  inherit (tikal.template) template;
  inherit (config.tikal.meta.nixos-context) tikal-secrets;
  inherit (config.tikal.meta.nixos-context.tikal-users) tikal-root;
  inherit (tikal-nixos) get-public-file;
  inherit (tikal.syslog) with-logger;
  tikal-user = tikal-root.user;
  tikal-group = tikal-root.group;
  log = tikal.prelude.log.add-context { file = ./tikal-core.nix; inherit nahual; };
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
        inherit tikal-secrets tikal-user tikal-group;
        openssl = "${pkgs.openssl}/bin/openssl";
        log = with-logger null;
      }
    )
  ;

  tikal-main-pub =
    get-public-file {
      path = tikal-secrets.tikal-public-key;
      user = tikal-user;
      group = tikal-group;
    }
  ;

  tikal-main-enc =
    get-public-file {
      path = tikal-secrets.tikal-private-key-enc;
      mode = 600;
      user = tikal-user;
      group = tikal-group;
  };
  init-script-name = "tikal-init";
in
  {
    options = {
      tikal.core = {
        init-script-name = mkOption {
          type = types.str;
          description = ''
            The name of the activation script that initializes Tikal.
            This can be used by other scripts to indicate they are
            dependent on Tikal.
          '';
          readOnly = true;
          default = init-script-name;
        };
      };
    };
    config = {
      environment.etc = with tikal-foundations; log.log-value "secret keys" {
        ${paths.relative.tikal-main-pub} = tikal-main-pub;
        ${paths.relative.tikal-main-enc} = tikal-main-enc;
      };

      system.activationScripts.${init-script-name}.text = "${unlock-script}";

      #boot.initrd = {
      #  postDeviceCommands = lib.mkAfter ''
      #    source ${unlock-script}
      #  '';
      #  extraFiles = {
      #    #tikal-main-pub = tikal-main-pub;
      #    #tikal-main-enc = tikal-main-enc;
      #  };
      #};
    };
  }

