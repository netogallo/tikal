{ lib, config, tikal, tikal-secrets, universe, nahual, pkgs, ... }:
let
  inherit (tikal.prelude) do;
  inherit (tikal.xonsh) xsh;
  inherit (lib) mkIf;
  inherit (config.tikal.meta.nixos-context) tikal-user;
  inherit (config.tikal.meta) nahuales;

  tor-socks-port = config.tikal.tor.socks-port;
  tikal-tor-secret-name = config.tikal.tor.secret-name;

  tikal-tor-set-hostname = nahual:
    let
      host = tikal-tor-hosts.${nahual};
    in
      ''
      export TOR_${nahual}="${host}"
      ''
  ;

  /**
  * Shell script which declares environmental variables
  * containing the hostnames of the onion service
  * of all nahuales.
  */
  tikal-tor-set-hostnames = do [
    lib.attrNames nahuales
    "$>" map tikal-tor-set-hostname
    "|>" lib.concatStringsSep "\n"
    "|>" pkgs.writeScriptBin "tikal-tor-set-hostnames"
  ];

  /**
  * This function computes the hostname for the onion service of
  * each of the nahuales by reading it from the "hostname" file
  * generated during tor initialization.
  */
  tikal-tor-host = nahual: _config:
    let
      public = tikal-secrets.get-secret-public-path {
        inherit nahual;
        name = config.tikal.tor.secret-name;
      };
    in
      lib.readFile "${public}/hostname"
  ;

  # Attribute set coontaining the address of the
  # hidden service that points to each of
  # the nahuales in the universe
  tikal-tor-hosts = lib.mapAttrs tikal-tor-host nahuales;

  /**
  * Script implementing a wrapper over ssh which connects to other
  * nahuales using the tor hidden service of each of the nahuales.
  */
  tikal-tor-ssh =
    xsh.write-script-bin {
      name = "tor-ssh";
      vars = { inherit tikal-tor-hosts; };
      script = { vars, ... }: ''
        from docopt import docopt
        import os
        
        progname = os.path.basename(__file__)
        doc = f"""
        Usage:
          tor-ssh --input=<ssh-key> [--print] <nahual>

        Options:
          --input=<ssh-key> -i <ssh-key>      The ssh private key to use to connect
          --print -p                          Show the command rather than running it
          <nahual>                            The nahual to connect via ssh.
        """

        args = docopt(doc)
        nahual = args['<nahual>']
        ssh_key = args['--input']
        hosts = ${vars.tikal-tor-hosts}
        host = hosts.get(nahual)
        only_print = args['--print']

        if host is None:
          known_hosts = ", ".join(hosts.keys())
          raise Exception(f"The specified nahual '{nahual}' is not known. Known nahuales in the universe are: '{known_hosts}'")

        host = host.strip()
        cmd_parts = [
          "${pkgs.openssh}/bin/ssh",
          "-o",
          'ProxyCommand="${pkgs.netcat}/bin/nc -x 127.0.0.1:${builtins.toString tor-socks-port} -X 5 %h %p"',
          "-i",
          f"{ssh_key}",
          f"${tikal-user}@{host}"
        ]
        cmd = " ".join(cmd_parts)

        if only_print:
          print(f"{cmd}")
        else:
          ${pkgs.bash}/bin/bash -c f"{cmd}"
      '';
    }
  ;

  onion-service-private-directory = tikal-secrets.get-secret-private-path {
    name = tikal-tor-secret-name;
  };
  secretKey = "${onion-service-private-directory}/hs_private_key";
in
  {
    imports = [ ../../shared/network/tor.nix ];
    config = {
      environment.systemPackages = [
        tikal-tor-set-hostnames
        tikal-tor-ssh
      ];
      services.tor = {
        enable = true;
        client = {
          enable = true;
          socksListenAddress = {
            addr = "127.0.0.1";
            port = tor-socks-port;
            IsolateDestAddr = true;
          };
        };

        relay.onionServices = {
          "${tikal-tor-secret-name}-ssh" = {
            inherit secretKey;
            map = [ { port = 22; target = { port = 22; }; } ];
          };
        };
      };
    };
  }
