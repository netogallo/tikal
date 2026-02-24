{ lib, ... }:
let
  inherit (lib) types mkOption;
in
  {
    options.network.tor = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Allow the nahuales defined in the tikal universe to be accessed
          as a "Onion Service". For all nahuales, an onion service
          will be created and all other nahuales will be aware of
          said onion service(s). This onion service can then be used
          to access other services ofered by the nahual. As an example,
          the nahuales will be able to use this service to ssh into
          each other.
        '';
      };

      secret-name = mkOption {
        default = "tikal-tor";
        type = types.str;
        readOnly = true;
        description = ''
          The identifier that will be used to tag the tor related
          secrets in the tikal secrets store.
        '';
      };
    };
  }
