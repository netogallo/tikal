{ lib, ... }:
let
  inherit (lib) types mkOption;
  nahual-wireguard = types.submodule {
    options.network.wireguard = {
      proper-endpoint = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = ''
          The endpoint (if any) for the nahual. If this option is specified, the public wireguard
          key corresponding to this nahual will be present in the wireguard configuration of
          all other nahuales using this value as the endpoint. The implication being that
          the nahual will be reachable by any other nahual via this endpoint. If a nahual
          is intended to act as a VPN server, this should be the public ip-address that
          the nahual is expected to have.
        '';
      };
      proper-ips = mkOption {
        default = [];
        type = types.listOf types.str;
        description = ''
          The ip-addresses which this nahual is allowed to use when communicating
          via the wireguard network. Theese ips get added to the cryptokey routing
          tables of all other nahuales.
        '';
      };
    };
  };
in
  {
    options.network.wireguard = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Enable networking between nahuales using a Wireguard VPN. When this option is enabled,
          wireguard keys will be generated and installed on all nahuales. Furthermore, the
          wireguard network topology will be configured following the universe specified
          options.
        '';
      };

      secret-name = mkOption {
        default = "tikal-wireguard";
        type = types.str;
        readOnly = true;
        description = "The name used to refer to the wireguard related secrets.";
      };
    };
  }
