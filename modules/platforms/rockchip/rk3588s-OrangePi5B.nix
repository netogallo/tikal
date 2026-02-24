{ tikal-platforms, ... }:
let
  inherit (tikal-platforms.rockchip) rk3588s-OrangePi5B;
in
  {
    config = with rk3588s-OrangePi5B; {
      nixpkgs.hostPlatform = rk3588s-OrangePi5B.system;
      boot.kernelPackages = rk3588s-OrangePi5B.kernel;
      hardware = {
        inherit firmware;
        deviceTree = device-tree;
      };

      # Non-Free Needed for firmware
      nixpkgs.config.allowUnfree = true;

      boot.loader = {
        generic-extlinux-compatible.enable = true;
        grub.enable = false;
      };

      rockchip.uBoot = rk3588s-OrangePi5B.uboot;

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
