{ config, tikal-foundationos, ... }:
let
  inherit (tikal-foundations) tikal-user tikal-group;
  nahual-nixos-base = _nahual: _context:
    {
      system.stateVersion = "25.05";
      users.users.${tikal-user} = {
        isNormalUser = true;
        group = tikal-group;
        extraGroups = [ "wheel" ];
      };
      security.sudo.enable = true;
    }
  ;
in
  {
    config = {
      tikal.build.modules =
        lib.mapAttrs
        (nahual: ctx: [(nahual-nixos-base nahual ctx)])
        config.nahuales
      ;
    };
  }
