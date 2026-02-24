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

        platform-module = mkOption {
          description = ''
            This is a path to a nixos module which should contian all the necessary
            configuration for NixOs to support the platform. It should be as minimal
            as possible, meaning it should mostly consist of:
              * Kernel and firmwares needed for the specific platform
              * The platform specific DTS for ARM systems
              * The bootloader type. Note that this module is not responsible for
                installing the bootloader, rather it must make sure that the
                root/boot partitions will contain all files needed by the bootloader.

            Note that this option is a store path (not an arbitrary module). The reason
            is that it will get added to the imports of the NixOs configuration
            when installing the nahual.
          '';
          type = types.path;
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

