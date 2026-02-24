{ lib, ... }:
let
  inherit (lib) types mkOption;
  platform = types.submodule {
    options = {
      system = mkOption {
        description = ''
          The nixpkgs target architecture of this platform.
        '';
        type = types.enum [ "x86_64-linux" "aarch64-linux" ];
      };

      /*
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
        type = types.package;
        };
      */
      installer-module = mkOption {
        description = ''
          This is a NixOs module that will be used to build the installation media.
          It must contain all the platform spacific items described in the
          'platfor-module' option as well as some additional declarations. Specifically
          it is expected to also define the options described in the
          "../../modules/installer/inputs.nix" module. The afromentioned module will
          be imported when building an installation media and this module will
          be expected to define all the requried (and potentially optional) settings
          in that module. Furthermore, this module is also expected to contain all
          necessary nixos configurations to generate an installation media. For
          example, if a SD card image is desired, make sure it overrides the necessary
          settings so the target platform can boot the SD card (ie. flash a specific
          u-boot build into the card).
        '';
        type = types.deferredModule;
      };
    };
  };
in
  {
    imports = [ ./rockchip.nix ];
    options = {
      platforms = mkOption {
        type = types.attrsOf platform;
      };
    };
  }
