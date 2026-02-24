{ config, universe, lib, tikal, tikal-secrets, ... }:
let
  inherit (lib) types mkOption mkIf;
  log = tikal.prelude.log.add-context { file = ./secrets.nix; };
  all-nahuales = log.log-value "all-nahuales" config.secrets.all-nahuales;

  locks-all-nahuales = tikal-secrets.locks-all-nahuales {
    inherit all-nahuales;
    nahuales = lib.attrNames universe.config.nahuales;
  };

  secrets-locks = lib.concatLists (lib.attrValues locks-all-nahuales);
in
  {
    imports = [
      ../../shared/config/secrets.nix
    ];
    config = mkIf config.secrets.enable {
      store-lock.items = secrets-locks;
    };
  }
