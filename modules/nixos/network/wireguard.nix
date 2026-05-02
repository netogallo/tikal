{ config, lib, nahual, tikal-secrets, universe, tikal, ... }:
let
  inherit (tikal.prelude) do;
  inherit (universe.config) nahuales;
  inherit (lib) mkIf;
  log = tikal.prelude.log.add-context { file = ./wireguard.nix; };
  tikal-interface = "tikal0";
  nahual-wg = nahuales.${nahual}.network.wireguard;
  wg-secret = config.tikal.wireguard.secret-name;
  wg-key-name = config.tikal.wireguard.key-name;
  wg-private = tikal-secrets.get-secret-private-path {
    name = wg-secret;
  };
  privateKeyFile = "${wg-private}/${wg-key-name}";

  /**
  Get the wireguard peer configuration of a nahual if
  possible. All nahuales which have been assigned an
  endpoint will be added as a peer to all other
  nahuales.
  */
  to-wireguard-peer = peer:
  let
    wg-config =
      if lib.hasAttr peer nahuales
      then nahuales.${peer}.network.wireguard
      else throw "The peer '${peer}' is not a nahual in the universe."
    ;
    wg-public = tikal-secrets.get-secret-public-path {
      nahual = peer;
      name = wg-secret;
    };
    endpoint-config =
      if wg-config.proper-endpoint == null
      then {}
      else {
        endpoint = wg-config.proper-endpoint;

        # Todo, this should be configuratble. In general,
        # it might be best to refactor tikal such that
        # all theese settings are exposed by enriching the
        # exisitng wireguard options
        persistentKeepalive = 25; 
      }
    ;
  in
    endpoint-config //
    {
      allowedIPs = wg-config.proper-ips;
      publicKey = builtins.readFile "${wg-public}/${wg-key-name}.pub";
    }
  ;
  other-nahuales = lib.filterAttrs (k: _: k != nahual) nahuales;
  peer-nahuales =
  let
    is-self-a-peer = _: peer-config:
      lib.elem nahual peer-config.network.wireguard.peers.nahuales
    ;
    nahuales-with-self =
      lib.attrNames (
        lib.filterAttrs is-self-a-peer other-nahuales
      )
    ;
  in
    lib.lists.unique (
      nahual-wg.peers.nahuales
      ++ nahuales-with-self
    )
  ;
  peers = do [
    lib.map to-wireguard-peer peer-nahuales
    # Remove peers that cannot be initially reached
    "$>" lib.filter (conf: conf != null)
    "|>" log.log-value "peers"
  ];
in
  {
    imports = [ ../../shared/network/wireguard.nix ];
    config = {
      networking = {
        wireguard = {
          enable = true;
          interfaces = {
            ${tikal-interface} = {
              inherit privateKeyFile peers;
              listenPort = nahual-wg.listen-port;
              ips = nahual-wg.proper-ips;
            };
          };
        };

        firewall = {
          allowedUDPPorts = mkIf (nahual-wg.listen-port != null) [ nahual-wg.listen-port ];
          extraForwardRules = mkIf nahual-wg.forwarding.enable ''
            iifname "${tikal-interface}" oifname "${tikal-interface}" accept
          ''; 
        };
      };

      boot.kernel = mkIf nahual-wg.forwarding.enable {
        sysctl = { "net.ipv4.ip_forward" = 1; };
      };
    };
  }
