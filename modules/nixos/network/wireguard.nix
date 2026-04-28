{ config, lib, nahual, tikal-secrets, universe, tikal, ... }:
let
  inherit (tikal.prelude) do;
  inherit (universe.config) nahuales;
  log = tikal.prelude.log.add-context { file = ./wireguard.nix; };
  tikal-interface = "tikal0";
  nahual-wg = nahuales.${nahual}.network.wireguard;
  wg-secret = config.tikal.wireguard.secret-name;
  wg-key-name = config.tikal.wireguard.key-name;
  wg-private = tikal-secrets.get-secret-private-path {
    name = wg-secret;
  };
  privateKeyFile = "${wg-private}/${wg-key-name}";
  tikal-wg-port = 51666;

  /**
  Get the wireguard peer configuration of a nahual if
  possible. All nahuales which have been assigned an
  endpoint will be added as a peer to all other
  nahuales.
  */
  to-wireguard-peer = peer:
  let
    wg-config = nahuales.${peer}.network.wireguard;
    wg-public = tikal-secrets.get-secret-public-path {
      nahual = peer;
      name = wg-secret;
    };
    endpoint-config =
      if wg-config.proper-endpoint == null
      then {}
      else { endpoint = wg-config.proper-endpoint; }
    ;
  in
    endpoint-config //
    {
      allowedIPs = wg-config.proper-ips;
      publicKey = builtins.readFile "${wg-public}/${wg-key-name}.pub";
    }
  ;
  peers = do [
    lib.attrNames nahuales
    # The nahual must not include itself as a peer
    "$>" lib.filter (n: n != nahual)
    "|>" lib.map to-wireguard-peer
    # Remove peers that cannot be initially reached
    "|>" lib.filter (conf: conf != null)
    "|>" log.log-value "peers"
  ];
in
  {
    imports = [ ../../shared/network/wireguard.nix ];
    config.networking.wireguard = {
      enable = true;
      interfaces = {
        ${tikal-interface} = {
          inherit privateKeyFile peers;
          listenPort = tikal-wg-port;
          ips = nahual-wg.proper-ips;
        };
      };
    };
  }
