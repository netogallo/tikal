{ lib, config, pkgs, universe, tikal, tikal-secrets, ... }:
let
  inherit (lib) mkIf;
  log = tikal.prelude.log.add-context { file = ./secrets.nix; };
  all-nahuales = config.secrets.all-nahuales;

  /**
  Store secrets are encrypted before being written to the nix store.
  Therefore, for these secrets to be usable, they must be decrypted,
  which is done through an activation script. This activation script
  will read the tikal master key (the tikal master key is made available
  at a fixed location during boot, usually by decrypting it from the
  store using a user-supplied passpharse) and use it to decrypt
  values from the nix store.
  */
  secrets-activation-scripts = 
    log.log-function-call
    "get-activation-scripts"
    tikal-secrets.get-activation-scripts
    {
      inherit all-nahuales;
      inherit (config.tikal.meta) nahual;
    }
  ;
in
  {
    imports = [
      ../../shared/config/secrets.nix
    ];
    config = mkIf config.secrets.enable {
      system.activationScripts.tikal-secrets-activate.text = secrets-activation-scripts;
    };
  }
