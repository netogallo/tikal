{ lib, ... }:
let
  inherit (lib) mkOption types;
in
  {
    options = {
      tikal.installer = {

        platform-name = mkOption {
          description = ''
            The name of the platform targeted by the installer.
          '';
          type = types.str;
        };

        platform-system = mkOption {
          description = ''
          The architecture target for nixpkgs that will run in this platform.
          '';
          type = types.enum [ "aarch64-linux" "x86_64-linux" ];
        };

        platform-config = mkOption {
          description = ''
            This contains an attribute set that will be added to
            the configuration. It should contain all the necessary
            options to enable the nixos configuration for the
            platform targeted by the installer.
          '';
          type = types.anything;
        };

        default-root-device = mkOption {
          description = ''
            The default block device on which the root filesystem
            is to be created. This will be used as the default
            by the installation script. However, it can be changed
            by the user.
          '';
          type = types.nullOr types.str;
          default = null;
        };

        default-boot-device = mkOption {
          description = ''
            The default block device where the bootloader will
            be installed.
          '';
          type = types.nullOr types.str;
          default = null;
        };

        bootloader-installer = mkOption {
          description = ''
            This string should point to a program that will
            be used to install the bootloader. The tikal installer
            will call this program and feed into its standard input
            a json which has the structure of the "tikal-bootloader-spec.nix"
            module.
          '';
          type = types.str;
        };
      };
    };
  }

