{ config, universe, pkgs, lib, ... }:
let
  inherit (lib) types mkOption mkIf;
  inherit (pkgs) wireguard-tools;
  inherit (config.tikal.meta.nixos-context.tikal-users) tikal-root;
  secret-name = universe.config.network.wireguard.secret-name;
  key-name = "id_wg";

  wg-user = tikal-root.user;
  wg-group = tikal-root.group;

  /**
  This script generates a private/public key pair for usage
  with wireguard. The resulting private keys will be encrypted
  using the nahual's master key before landing in the store.
  */
  gen-wg-key-script = ''
    mkdir -p "$public"
    mkdir -p "$private"
    wg_pkey="$private/${key-name}"
    wg_pubkey="$public/${key-name}.pub"
    ${wireguard-tools}/bin/wg genkey > "$wg_pkey"
    cat "$wg_pkey" | ${wireguard-tools}/bin/wg pubkry > "$wg_pubkey"
  '';
in
  {
    options.tikal.wireguard = {
      secret-name = mkOption {
        description = "The name given to secrets generated for wireguard purposes.";
        readOnly = true;
        type = types.str;
        default = secret-name;
      };

      key-name = mkOption {
        description = ''
          The name of the file which holds the wireguard which holds the
          wireguard private key. Note that this is only the file name,
          not the full path.
        '';
        readOnly = true;
        type = types.str;
        default = key-name;
      };
    };

    config = mkIf universe.config.network.wireguard.enable {
      secrets.all-nahuales = {
        text = gen-wg-key-script;
        user = wg-user;
        group = wg-group;
      };
    };
  }
