{
  config
, lib
, tikal
, pkgs
, tikal-secrets
, tikal-foundations
, ...
}:
let
  inherit (tikal-foundations.system) tikal-user;
  inherit (tikal.prelude) do;
  inherit (tikal-secrets) get-secret-public-path get-secret-private-path;
  inherit (tikal.xonsh) xsh;
  inherit (lib) types mkIf mkOption;
  inherit (pkgs) gettext;
  log = tikal.prelude.log.add-context { file = ./tor.nix; };
  tor-sync = pkgs.tor.overrideAttrs (new: old: {
    patches =
      old.patches
      ++ [ ./tor/0001-Command-line-option-to-pre-initialize-files.patch ];
  });

  # Name of the tikal-secret that is asociated with
  # this module
  tikal-tor-secret-name = "tikal-tor";

  # Port to be used to create a socks proxy to
  # access tor.
  # Todo: make it configurable
  tor-socks-port = 39080;

  tikal-onion-service-torrc =
    pkgs.writeText "torrc" ''
      HiddenServiceDir $private
      HiddenServicePort 22 127.0.0.1:22
      ''
  ;

  # Script that generates a hidden service. This is used
  # to create a hidden serivce for each nahual which
  # can then be used by other nahuales to communicate
  # with each other.
  tikal-onion-service-secrets-script =
    ''
    mkdir -p $public
    echo $USER
    workdir=$(mktemp -d)
    cat "${tikal-onion-service-torrc}" \
      | private="$private" ${gettext}/bin/envsubst \
      > "$workdir/torrc"
    cat "$workdir/torrc"
    echo "${tor-sync}"
    ${tor-sync}/bin/tor --init-files -d "$workdir" -f "$workdir/torrc"

    # Tor does not want exectue permissions on directory
    # However, this will be compressed with tar, so
    # execution permission will be needed
    chmod +x $private
    cp $private/hs_*_secret_key $private/hs_private_key
    mv $private/hostname $public/
    mv $private/hs_*_public_key $public/
    rm -rf $private/authorized_clients
    echo "canary" > "$private/canary"
    cp $workdir/torrc $private/
    ''
  ;

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

  tikal-tor-host = nahual: _config:
    let
      public = get-secret-public-path {
        inherit nahual;
        name = tikal-tor-secret-name;
      };
    in
      lib.readFile "${public}/hostname"
  ;

  # Attribute set coontaining the address of the
  # hidden service that points to each of
  # the nahuales in the universe
  tikal-tor-hosts = lib.mapAttrs tikal-tor-host config.nahuales;

  tikal-tor-set-hostname = nahual:
    let
      host = tikal-tor-hosts.${nahual};
    in
      ''
      export TOR_${nahual}="${host}"
      ''
  ;

  tikal-tor-set-hostnames = do [
    lib.attrNames config.nahuales
    "$>" map tikal-tor-set-hostname
    "|>" lib.concatStringsSep "\n"
    "|>" pkgs.writeScriptBin "tikal-tor-set-hostnames"
  ];

  tor-network-module = nahual: _config:
    # This produces a nixos module which should
    # do the following:
    # 1. Enables tor
    # 2. Creates a onion service
    # 3. Exposes openssh on that onion service
    # 4. Creates scripts to easily ssh into
    #    other servers via tor
    let
      onion-service-private-directory = get-secret-private-path {
        name = tikal-tor-secret-name;
      };
      secretKey = "${onion-service-private-directory}/hs_private_key";
    in
    {
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
  ;

  tor-modules = name: config:
    lib.map
    (mod: mod name config)
    [ tor-network-module ]
  ;
  tor-cfg = config.networks.tor;
in
{
  options = {
    networks.tor = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = "Enable the use of tor for nahuales to communicate with each other.";
      };
    };
  };

  config = mkIf tor-cfg.enable {
    
    tikal = {
      build.modules = lib.mapAttrs tor-modules config.nahuales;
    };

    secrets.all-nahuales = {
      ${tikal-tor-secret-name} = {
        text = tikal-onion-service-secrets-script;
      };
    };

  };
}
