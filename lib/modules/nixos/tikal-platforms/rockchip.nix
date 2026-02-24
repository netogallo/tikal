{ nixos-rockchip, build-system, ... }:
let
  # Rockchip devices are ARM only
  system = "aarch64-linux";
  inherit (nixos-rockchip.packages.${system}) brcm43752;

  # Nixos rockchip always builds kernels targeting aarch64. Different
  # system results in cross-compilation.
  inherit (nixos-rockchip.legacyPackages.${build-system}) kernel_linux_6_17_orangepi5b_stable;
  inherit (nixos-rockchip.nixosModules) dtOrangePi5B sdImageRockchipInstaller;
  inherit (nixos-rockchip.packages.${system}) uBootOrangePi5B;
in
  {
    rk3588s-OrangePi5B = {
      system = "aarch64-linux";
      kernel = kernel_linux_6_17_orangepi5b_stable;
      firmware = [ brcm43752 ];
      device-tree = (dtOrangePi5B {}).hardware.deviceTree;
      uboot = uBootOrangePi5B;
      sd-image-module = "${nixos-rockchip}/modules/sd-card/sd-image-rockchip-installer.nix";
    };
  }
