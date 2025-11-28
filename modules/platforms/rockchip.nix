{ tikal, config, lib, ... }:
let
  inherit (tikal.platforms.platforms) rk3588s-OrangePi5B;
  inherit (lib) types mkIf mkOption;
  rk3588s-OrangePi5B-module = { config, ... }:
  {
    options = {
      tikal.platforms.rk3588s-OrangePi5B = {
        enable = mkOption {
          default = false;
          type = types.bool;
          description = "Enable the configuration for the rk3588-OrangePi5B.";
        };
      };
    };
    config =
      mkIf
      config.tikal.platforms.rk3588s-OrangePi5B.enable
      rk3588s-OrangePi5B.nixos-config
    ;
  };

  rockchip-module = _name: _config:
    [
      {
        imports = [
          rk3588s-OrangePi5B-module
        ];
      }
    ]
  ;
in
  {
    tikal.build.modules = lib.mapAttrs rockchip-module config.nahuales;
  }
  
