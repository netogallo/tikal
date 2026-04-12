{ lib, ... }:
let
  inherit (lib) mkOption types;
  nahual-remote-access = types.submodule {
    options = {
      remote-access.openssh = {
        administrator = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Indicates whether this nahuale's tikal administrator account
            has ssh access to the tikal administrator account of other
            nahuales.
          '';
        };
      };
    };
  };
in
  {
    options = {
      nahuales = lib.mkOption {
        type = types.attrsOf nahual-remote-access;
      };

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
