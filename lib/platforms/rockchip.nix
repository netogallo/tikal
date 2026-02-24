{
  tikal,
  ...
}:
let
  log = tikal.prelude.log.add-context { file = ./rockchip.nix; };
in
  {
    config.platforms = {
      "rk3588s-OrangePi5B" = {
        system = "aarch64-linux";
        installer-module = ../../modules/platforms/rockchip/rk3588s-OrangePi5B-installer.nix;
      };
    };
  }
