{
  config
, lib
, tikal
, pkgs
, universe-context
, tikal-secrets
, ...
}:
let
  inherit (tikal.secrets) get-secret-path;
  inherit (tikal.xonsh) xsh;
  inherit (tikal.sync) nahual-sync-script;
  inherit (lib) types mkIf mkOption;
  inherit (pkgs) gettext;
  #inherit (nahual-pkgs config.nahuales) tikal-secrets;
  log = tikal.prelude.log.add-context { file = ./tor.nix; };
  tor-sync = pkgs.tor.overrideAttrs (new: old: {
    patches = old.patches ++ [ ./tor/0001-Command-line-option-to-pre-initialize-files.patch ];
  });

  tikal-onion-service-torrc =
    pkgs.writeText "torrc" ''
      HiddenServiceDir $private
      HiddenServicePort 22 127.0.0.1:22
      ''
  ;
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

  tikal-onion-service = name: config:
    let
      torrc-init = pkgs.writeText "torrc" ''
        HiddenServiceDir $private
        HiddenServicePort 22 127.0.0.1:22
      '';
      onion-secrets = tikal-secrets.${name}.secret-folders {
        tikal = {
          # The secrets builder will encrypt the contents of $out
          # before completing. Therefore they will not land on the
          # nix store. However, they will be accessible while
          # the builder is running and might remain in your
          # system if '--keep-failed-runs' is used.
          script = ''
            mkdir -p $public
            echo $USER
            workdir=$(mktemp -d)
            cat "${torrc-init}" | private="$private" ${gettext}/bin/envsubst > "$workdir/torrc"
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
          '';
        };
      };
    in
      log.log-value { nahual = name; } "Tor hidden service" onion-secrets
  ;

  tikal-onion-services = lib.mapAttrs tikal-onion-service config.nahuales;
  tor-socks-port = 39080;

  to-tor-ssh = secrets:
    let
      tor-hosts =
        lib.mapAttrs
        (_: onion-service: lib.readFile "${onion-service.secrets.tikal.public}/hostname")
        tikal-onion-services
      ;
    in
      xsh.write-script-bin {
        name = "tor-ssh";
        vars = { inherit tor-hosts; };
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
          hosts = ${vars.tor-hosts}
          host = hosts.get(nahual)
          only_print = args['--print']

          if host is None:
            known_hosts = ", ".join(hosts.keys())
            raise Exception(f"The specified nahual '{nahual}' is not known. Known nahuales in the universe are: '{known_hosts}'")

          host = host.strip()
          cmd = [
            "${pkgs.openssh}/bin/ssh",
            "-o",
            "ProxyCommand=${pkgs.netcat}/bin/nc -x 127.0.0.1:${builtins.toString tor-socks-port} -X 5 %h %p",
            "-i",
            f"{ssh_key}",
            f"{nixos@{host}"
          ]

          if only_print:
            print(" ".join(cmd))
          else:
            @(args)
        '';
      }
  ;

  tikal-tor-set-hostname = nahual:
    let
      public = get-secret-public-path {
        inherit nahual;
        name = tikal-tor-secret-name;
      };
    in
      ''
      export TOR_${nahual}=$(cat ${public}/hostname)
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
      tor-ssh = to-tor-ssh config;
    in
    {
      config = {
        environment.systemPackages = [
          tikal-tor-set-hostnames
          (log.log-debug { inherit nahual; } "tor-ssh: ${tor-ssh}" tor-ssh)
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

  tor-modules = name: config: lib.map (mod: mod name config) [ tor-network-module ];
  tor-cfg = config.networks.tor;
in
{
  options = {
    networks.tor = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = "Enable the use of tor for devices to communicate with each other.";
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
