{
  config,
  pkgs,
  tikal-rockchip,
  tikal-platforms,
  ...
}:
let
  inherit (tikal-platforms.rockchip) rk3588s-OrangePi5B;
  bootloader-installer = tikal-rockchip.uboot-installer {
    uboot-image = rk3588s-OrangePi5B.uboot;
  };
in
{
  imports = [
    ./shared.nix
    ./rk3588s-OrangePi5B.nix
  ];
  config = {
    tikal.installer = {
      platform-name = "rk3588s-OrangePi5B";
      platform-system = rk3588s-OrangePi5B.system;
      platform-module = ./rk3588s-OrangePi5B.nix;
      default-root-device = "/dev/mmcblk0";
      default-boot-device = "/dev/mmcblk0";
      inherit bootloader-installer;
    };
  };
}
