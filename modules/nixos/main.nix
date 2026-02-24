{ lib, config, ... }:
let
  inherit (lib) types mkOption;
  inherit (config.tikal.meta.nixos-context) tikal-user tikal-group;
in
  {
    imports = [
      ./tikal-meta.nix
      ./config/secrets.nix
      ./system/unlock.nix
      ./network/tor.nix
      ./remote-access/ssh.nix
    ];
    config = {
      system.name = config.tikal.meta.nahual;
      networking.hostName = config.tikal.meta.nahual;
      users.users.${tikal-user} = {
        isNormalUser = true;
        group = tikal-group;
        extraGroups = [ "wheel" ];
      };
      users.groups.${tikal-group} = {};
      security.sudo.enable = true;
    };
  }
