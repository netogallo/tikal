{ lib, tikal, universe, pkgs, ... }:
let
  inherit (lib) mkIf mkOption types;
  inherit (pkgs) gettext;
  log = tikal.prelude.log.add-context { file = ./tor.nix; };
  tor-universe = log.log-value "tor-universe" universe.config.network.tor;
  tikal-tor-secret-name = tor-universe.secret-name;
  tor-sync = pkgs.tor.overrideAttrs (new: old: {
    patches =
      old.patches
      ++ [ ./tor/0001-Command-line-option-to-pre-initialize-files.patch ];
  });
  tikal-onion-service-torrc =
    pkgs.writeText "torrc" ''
      HiddenServiceDir $private
      HiddenServicePort 22 127.0.0.1:22
      ''
  ;
  /** Script that generates a hidden service. This is used
  * to create a hidden serivce for each nahual which
  * can then be used by other nahuales to communicate
  * with each other.
  */
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
in
  {
    options.tikal.tor = {
      secret-name = mkOption {
        description = ''
          The name that will be used to identify the secrets generated
          for Tor. A hidden service is created for each of the nahuales
          and the cryptographic keys of said service will be the secret.
        '';
        readOnly = true;
        type = types.str;
        default = tikal-tor-secret-name;
      };
      socks-port = mkOption {
        description = ''
          The port on which the socks proxy will be started for the
          tikal TOR instance.
        '';
        type = types.number;
        default = 39080;
      };
    };
    config.secrets.all-nahuales = mkIf tor-universe.enable {
      ${tikal-tor-secret-name} = {
        text = tikal-onion-service-secrets-script;
      };
    };
  }

