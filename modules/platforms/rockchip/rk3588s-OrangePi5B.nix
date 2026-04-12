{
  tikal-platforms,
  lib,
  config,
  ...
}:
let
  inherit (tikal-platforms.rockchip) rk3588s-OrangePi5B;
  inherit (lib) mkOption mkIf types;
  inherit (config.tikal.platforms.rockchip.rk3588s-OrangePi5B) enable;
in
  {
    options = {
      tikal.platforms.rockchip.rk3588s-OrangePi5B.enable = mkOption {
        description = "Enable the configuration for the OrangePi5B SBC";
        type = types.bool;
        default = false;
      };
    };
    config = mkIf enable {
      nixpkgs.hostPlatform = rk3588s-OrangePi5B.system;
      boot.kernelPackages = rk3588s-OrangePi5B.kernel;
      hardware = {
        inherit (rk3588s-OrangePi5B) firmware;
        deviceTree = rk3588s-OrangePi5B.device-tree;
      };

      # Non-Free Needed for firmware
      nixpkgs.config.allowUnfree = true;

      boot.loader = {
        generic-extlinux-compatible.enable = true;
        grub.enable = false;
      };

      # ZFS must be disabled for arm systems
      nixpkgs.overlays = [
        (final: super: {
          zfs = super.zfs.overrideAttrs (_: {
            meta.platforms = [ ];
          });
        })
      ];
    };
  }
