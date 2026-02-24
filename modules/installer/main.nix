{
  config,
  pkgs,
  tikal,
  tikal-config,
  platform-name,
  platform-spec,
  tikal-installer,
  ...
}:
let
  inherit (tikal-config) nixos-version;
  installer-package = tikal-installer.package config.tikal.installer;
in
  {
    imports = [
      ./inputs.nix
    ];
    config = {
      system.name = "tikal-installer";
      system.stateVersion = nixos-version;
      environment.systemPackages = with pkgs; [
        gptfdisk
        openssh
        git
        installer-package
      ];
      networking.networkmanager.enable = true;
      networking.wireless.enable = false;
    };
  }

