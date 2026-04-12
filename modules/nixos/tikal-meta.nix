{ universe, nahual, lib, ... }:
let
  inherit (lib) mkOption types;
  universe-module = universe;
  inherit (universe-module.config.tikal.context) sync;
  nahual-meta = types.submodule {};
in
  {
    imports = [ ../shared/tikal-meta.nix ];
    options = {
      tikal.meta = {
        nahual = mkOption {
          type = types.str;
          description = ''
          The name of the nahual. This option cannot be changed. However, it can
          be accessed by other nixos modules for customization.
          '';
          default = nahual;
          readOnly = true;
        };

        nahuales = mkOption {
          type = types.attrsOf nahual-meta;
          description = ''
          This field contains metadata of other nahuales which is visible to
          the nixos configuration of a specific nahual.
          '';
          default = lib.mapAttrs (_: _: {}) universe.config.nahuales;
          readOnly = true;
        };

        apps-context = {
          nahual-private = mkOption {
            type = types.str;
            description = ''
            The relative location of the nahual's private directory. Note that this
            directory should not be part of the flake/git repo. This is only included
            as a reference.
            '';
            default = sync.nahuales.${nahual}.private.root;
            readOnly = true;
          };

          tikal-dir = mkOption {
            type = types.str;
            description = ''
            The relative path from the universe's flake where the tikal
            configuration folder of this universe is located. This option is
            for information purposes and cannot be changed.
            '';
            default = sync.tikal-dir;
            readOnly = true;
          };
        };
      };
    };
  }
