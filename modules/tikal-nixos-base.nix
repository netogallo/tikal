{ config, lib, tikal-foundations, ... }:
let
  inherit (tikal-foundations.system) tikal-user tikal-group;
  universe-id = config.universe.id;
  nahual-nixos-base = nahual: _context: { config, lib, ... }:
    let
      inherit (lib) mkOption types;
    in
      {
        options = {
          tikal.${universe-id}.meta = {
            nahual = mkOption {
              type = types.str;
              default = nahual;
              description = ''
                The nahual for which this nixos configuration
                is for.
              '';
            };
            tikal-user = mkOption {
              type = types.str;
              default = tikal-user;
              description = ''
                The username created by Tikal which is responsible
                for managing this Nahual within this universe.
              '';
            };
            tikal-group = mkOption {
              default = tikal-group;
              description = ''
                The group created by Tikal which is also the group
                of the Tikal user.
              '';
            };
          };
        };

        config = {

          assertions = with config.tikal.${universe-id}; [
            {
              assertion = meta.nahual == nahual;
              message = "Option 'tikal.${universe-id}.meta.nahual' is for reference, cannot be changed.";
            }
            {
              assertion = meta.tikal-user == tikal-user;
              message = "Option 'tikal.${universe-id}.meta.tikal-user' is for reference and cannot be changed.";
            }
            {
              assertion = meta.tikal-group == tikal-group;
              message = "Option 'tikal.${universe-id}.meta.tikal-group' is for reference and cannot be changed.";
            }
          ];

          system.stateVersion = "25.05";
          users.users.${tikal-user} = {
            isNormalUser = true;
            group = tikal-group;
            extraGroups = [ "wheel" ];
          };
          users.groups.${tikal-group} = {};
          security.sudo.enable = true;
        };
      }
  ;
in
  {
    options = with lib; {
      universe = {
        id = mkOption {
          type = types.str;
          description = ''
            A value that uniquely identifies the tikal universe. When mixing
            NixOs configurations of from different universes, this value
            must be unique for all of the universes. Furthermore, the
            Tikal NixOs configurations provide universe-related metadata
            under the config option "tikal.{universe.id}.meta", meaning
            this identifier should be used to access the universe's metadata
            if needed.
          '';
        };
      };
    };

    config = {
      tikal.build.modules =
        lib.mapAttrs
        (nahual: ctx: [(nahual-nixos-base nahual ctx)])
        config.nahuales
      ;
    };
  }
