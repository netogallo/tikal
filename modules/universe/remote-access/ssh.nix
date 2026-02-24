{ lib, ... }:
let
  inherit (lib) mkOption types;
in
  {
    options = {
      remote-access.openssh = {
        enable = mkOption {
          default = false;
          type = types.bool;
          description = "Enable ssh access amongst nahualees.";
        };

        secret-name = mkOption {
          default = "tikal-ssh";
          type = types.str;
          readOnly = true;
        };
      };
    };
  }
