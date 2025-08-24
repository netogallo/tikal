{
  config
, lib
, tikal
, pkgs
, nahual-pkgs
, universe-context
, ...
}:
let
  inherit (tikal.xonsh) xsh;
  inherit (tikal.sync) nahual-sync-script;
  inherit (lib) types mkIf mkOption;
  inherit (pkgs) gettext;
  inherit (nahual-pkgs config.nahuales) tikal-secrets;
  log = tikal.prelude.log.add-context { file = ./tor.nix; };
  tor-sync = pkgs.tor.overrideAttrs (new: old: {
    patches = old.patches ++ [ ./tor/0001-Command-line-option-to-pre-initialize-files.patch ];
  });

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

  tor-network-module = name: config:
    # This produces a nixos module which should
    # do the following:
    # 1. Enables tor
    # 2. Creates a onion service
    # 3. Exposes openssh on that onion service
    # 4. Creates scripts to easily ssh into
    #    other servers via tor
    let
      onion-services = tikal-onion-services.${name};
      secrets = onion-services.secrets;
    in
    {
      imports = [ onion-services.module ];
      config = {
        services.tor = {
          enable = true;
          relay.onionServices = {
            "tikal" = {
              secretKey = "${secrets.tikal.private}/hs_private_key";
              map = [ { port = 22; target = { port = 22; }; } ];
            };
          };
        };
      };
    }
  ;

  tor-modules = name: config: lib.map (mod: mod name config) [ tor-network-module ];

  sync-script = nahual-sync-script {
    name = "tikal-host-onion-service";
    description = ''
    This script does the following:
      1. Create the public keys for the onion services
         of each of the nahuales. This is achieved using
         a patched tor server which initializes onion
         services w/o opening any network connections.
      2. Encrypt and copy these secrets to the public
         directory of each Nahual. This way, the nahuales
         can be built and the private keys will be available
         in each of the images.
    '';
    each-nahual = {
      build-step = ''
        ${tor-sync}/bin/tor --init-files -d f"{out}"
      '';
    };
  };
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
      sync.scripts = [
        sync-script
      ];

      build.modules = lib.mapAttrs tor-modules config.nahuales;
    };
  };
}
