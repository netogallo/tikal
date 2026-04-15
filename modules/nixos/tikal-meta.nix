{
  universe,
  nahual,
  lib,
  tikal-nixos-context,
  tikal-flake-context,
  ...
}:
let
  inherit (lib) mkOption types;
  universe-module = universe;
  inherit (universe-module.config.tikal.context) sync;
  nahual-meta = types.submodule {};
  inherit (tikal-flake-context.nahuales.${nahual}.public) tikal-keys;
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

        nixos-context = {
          tikal-secrets = {
            tikal-public-key = mkOption {
              type = types.str;
              description = ''
                The location where the public key corresponding to the 'tikal-private-key'
                will be located.
              '';
              readOnly = true;
              default = tikal-keys.tikal_main_pub;
            };

            tikal-private-key = mkOption {
              type = types.str;
              description = ''
                The location where the 'tikal-private-key' is located. Each nahual is assigend
                a dedicated cryptographic key which is used for many purposes including:
                * Ensuring sensitive credentials are encrypted in the nix store.
                * Performing cryptographic signatures for authentication purposes.
              '';
              readOnly = true;
              default = tikal-nixos-context.tikal-secrets.tikal-private-key;
            };

            tikal-private-key-enc = mkOption {
              type = types.str;
              description = ''
                The 'tikal-private-key' is distributed in an encrypted form using a 16 byte
                passphrase. When the key is used for the first time (while activating the
                relevant nixos configuration or installing a Tikal system), the key needs
                to be decrypted in order to access the encrypted store credentials. This file
                contains the encrypted version of said key.
              '';
              readOnly = true;
              default = tikal-keys.tikal_main_enc;
            };
          };
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
