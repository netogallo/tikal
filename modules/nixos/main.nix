{ lib, config, ... }:
let
  inherit (lib) types mkOption;
  inherit (config.tikal.meta.nixos-context.tikal-users) tikal-root;
in
  {
    imports = [
      ./tikal-meta.nix
      ./config/secrets.nix
      ./system/unlock.nix
      ./network/tor.nix
      ./network/wireguard.nix
      ./remote-access/ssh.nix
      ../platforms/platforms.nix
    ];
    config = {
      system.name = config.tikal.meta.nahual;
      networking.hostName = config.tikal.meta.nahual;
      users.users.${tikal-root.user} = {
        isNormalUser = true;
        group = tikal-root.group;
        extraGroups = [ "wheel" ];
      };
      users.groups.${tikal-root.group} = {};
      security.sudo.enable = true;
    };
  }
