{ lib, config, pkgs, universe, tikal, tikal-secrets, ... }:
let
  inherit (lib) mkIf;
  log = tikal.prelude.log.add-context { file = ./secrets.nix; };
  all-nahuales = config.secrets.all-nahuales;
  locks-all-nahuales = tikal-secrets.locks-all-nahuales {
    inherit all-nahuales;
    nahuales = lib.attrNames universe.config.nahuales;
  };
  secrets = log.log-value "secrets" locks-all-nahuales.${config.tikal.meta.nahual};
in
  {
    imports = [
      ../../shared/config/secrets.nix
    ];
    config = mkIf config.secrets.enable {
      system.activationScripts.tikal-secrets-activate.text =
        tikal-secrets.secrets-activation-script secrets
      ;
    };
  }
