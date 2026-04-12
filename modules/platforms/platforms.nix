{ pkgs, lib, nixos-rockchip, ... }: {
  imports = [
    ./rockchip/rk3588s-OrangePi5B.nix
  ];
  config._module.args = {
    tikal-platforms =
      import
      ../../lib/modules/nixos/tikal-platforms.nix
      {
        inherit nixos-rockchip;
        build-system = pkgs.stdenv.system;
      }
    ;
  };
}
