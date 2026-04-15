{
  universe,
  lib,
  tikal-nixos,
  tikal-flake-context,
  ...
}:
let
  inherit (lib) mkOption types;
  universe-module = universe;
  inherit (universe-module.config) tikal-user;
  inherit (universe-module.config.tikal.context) sync;
  nahual-meta = types.submodule {};
  tikal-group = tikal-user;

in
  {
    options.tikal.meta = {
      nixos-context.tikal-users = {
        tikal-root = {
          user = mkOption {
            type = types.str;
            description = ''
              The username of the admin account that will be used by Tikal
              for mantainance purposes of the nahuales. This user will exist
              in all nahuales and will run services such as automatic updates.
            '';
            readOnly = true;
            default = tikal-user;
          };

          group = mkOption {
            type = types.str;
            description = ''
              The group corresponding to the tikal admin account.
            '';
            readOnly = true;
            default = tikal-group;
          };

          home = mkOption {
            type = types.str;
            description = ''
              The home directory of the Tikal user.
            '';
            default = "/home/${tikal-user}";
            readOnly = true;
          };
        };
      };
    };
  }
