{ get-public-file, nahual, nahual-config, universe, ... }: { lib, pkgs, ... }:
let
  flake-attrs = universe.flake;
  config = universe.config;
  tikal-public = nahual-config.public;
  tikal-keys = tikal-public.tikal-keys;
  tikal-master-key = "/etc/tikal/id_tikal";
  tikal-enc-key = "tikal/id_tikal.enc";
  ssh-keygen = "${pkgs.openssh}/bin/ssh-keygen";
  unlock-script = pkgs.writeScript "unlock" ''
    echo "This Tikal image has not been unlocked. Please enter the unlock key when prompted"
    TMP_KEY=$(mktemp)
    SSH_ENC="/etc/${tikal-enc-key}"
    cp "$SSH_ENC" "$TMP_KEY"
    SSH_OUT="${tikal-master-key}"

    decrypt_tikal_master_key() {
      while true; do
        read -s -p "Enter SSH key passphrase: " PASSPHRASE
        echo "Your passphrase: $PASSPHRASE"
        ${ssh-keygen} -p -f "$TMP_KEY" -N "" -P "$PASSPHRASE"
        RESULT="$?"

        if [ "$RESULT" == "0" ]; then
          mv "$TMP_KEY" "$SSH_OUT"
          break
        else
          echo "Incorrect password was supplied. Try again"
        fi
          
      done
    }

    if [ ! -f "$SSH_OUT" ]; then
      decrypt_tikal_master_key
    fi
  '';
in
  {
    config = {
      environment.etc = {
        "tikal/id_tikal.pub" = get-public-file { path = tikal-keys.tikal_main_pub; };
        ${tikal-enc-key} = get-public-file { path = tikal-keys.tikal_main_enc; mode = 600; };
      };
      boot.postBootCommands = lib.mkAfter ''
        source "${unlock-script}"
      '';
    };
  }
