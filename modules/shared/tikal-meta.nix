{ universe, lib, ... }:
let
  inherit (lib) mkOption types;
  universe-module = universe;
  inherit (universe-module.config) tikal-user;
  inherit (universe-module.config.tikal.context) sync;
  nahual-meta = types.submodule {};
in
  {
    options.tikal.meta = {
      nixos-context = {
        tikal-user = mkOption {
          type = types.str;
          default = tikal-user;
          description = ''
            The username created by Tikal which is responsible
            for managing this Nahual within this universe.
          '';
          readOnly = true;
        };
        tikal-group = mkOption {
          default = tikal-user;
          readOnly = true;
          description = ''
            The group created by Tikal which is also the group
            of the Tikal user.
          '';
        };
      };
    };
  }
