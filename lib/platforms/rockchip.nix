{
  nixos-rockchip,
  system,
  lib,
  nixpkgs,
  ...
}:
let
  inherit (nixos-rockchip.packages.${system})
    uBootOrangePi5B brcm43752;
  inherit (nixos-rockchip.legacyPackages.${system})
    kernel_linux_6_17_orangepi5b;
  inherit (nixos-rockchip.nixosModules)
    dtOrangePi5B sdImageRockchipInstaller;
  noZFS = {
    nixpkgs.overlays = [
      (final: super: {
        zfs = super.zfs.overrideAttrs (_: {
          meta.platforms = [ ];
        });
      })
    ];
  };
  get-install-media = platform: { installer-module }:
    let
      sd-module = {
        imports = [ noZFS sdImageRockchipInstaller ];
        config =
          platform.nixos-config //
          {
            rockchip.uBoot = platform.uboot;
          }
        ;
      };
      sd-nixos = 
        nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ sd-module installer-module ];
        }
      ;
    in
      {
        sd-image = sd-nixos.config.system.build.sdImage;
      }
  ;
  rk3588s-OrangePi5B = rec {
    name = "rk3588s-OrangePi5B";
    device-tree = (dtOrangePi5B {}).hardware.deviceTree;
    kernel = kernel_linux_6_17_orangepi5b;
    firmware = [ brcm43752 ];
    uboot = uBootOrangePi5B;
    install-device = "/dev/mmcblk0";
    host-platform = "aarch64-linux";
    nixos-config = {
      boot.kernelPackages = kernel;

      # Non-Free Needed for firmware
      nixpkgs.config.allowUnfree = true;
      hardware.firmware = firmware;
      hardware.deviceTree = device-tree;
      boot.loader.generic-extlinux-compatible.enable = true;
      boot.loader.grub.enable = false;
      nixpkgs.hostPlatform = host-platform;

      # Disable ZFS
      nixpkgs.overlays = [
        (final: super: {
          zfs = super.zfs.overrideAttrs (_: {
            meta.platforms = [ ];
          });
        })
      ];
    };
  };
  with-installers = _k: platform:
    platform // { get-install-media = get-install-media platform; }
  ;
in
  {
    platforms = lib.mapAttrs with-installers {
      inherit rk3588s-OrangePi5B;
    };
  }
