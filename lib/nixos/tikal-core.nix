{ get-public-file, tikal, nahual, nahual-modules, nahual-config, universe, pkgs, lib, ... }:
let
  pkgs' = pkgs;
  lib' = lib;
  module = { lib, pkgs, ... }:
    let
      core-scope = lib'.makeScope pkgs'.newScope (self: {
        inherit tikal nahual nahual-config nahual-modules universe;
        tikal-foundations = self.callPackage ./tikal-foundations.nix {};
        tikal-context = self.callPackage ./tikal-context.nix {};
        tikal-secrets = self.callPackage ./tikal-secrets.nix {};
        tikal-log = self.callPackage ./tikal-log.nix {};
      });
      inherit (core-scope) tikal-context tikal-foundations;
      flake-attrs = universe.flake;
      config = universe.config;
      tikal-keys = nahual-config.public.tikal-keys;
      tikal-paths = tikal-foundations.paths;
      age = "${pkgs.age}/bin/age";
      expect = "${pkgs.expect}/bin/expect";
      unlock-script = pkgs.writeScript "unlock" ''
        echo "This Tikal image has not been unlocked. Please enter the unlock key when prompted"
    
        decrypt_tikal_master_key() {
          TMP_KEY=$(mktemp)
          while true; do
            read -s -p "Enter SSH key passphrase: " PASSPHRASE

            AGE_SCRIPT='
            spawn ${age} -d -o '"$TMP_KEY"' "${tikal-main-enc.source}"
            expect "Enter passphrase"
            send "'"$PASSPHRASE"'\r"
            expect {
              "error" {
                expect eof
                exit 1
              } eof {
                exit 0
              }
            }
            '

            echo "DEBUG age script: $AGE_SCRIPT"
            ${expect} -c "$AGE_SCRIPT"
            RESULT="$?"
    
            if [ "$RESULT" == "0" ]; then
              # OUT_DIR=$(dirname "${tikal-paths.tikal-main}")
              # mv "$TMP_KEY" "${tikal-paths.tikal-main}"
              mkdir -p /run/keys/tikal
              mv "$TMP_KEY" /run/keys/tikal/id_tikal
              echo "Success! Writing key to ${tikal-paths.tikal-main}"
              read -s -p "Press enter to continue: " X
              break
            else
              echo "Incorrect password was supplied. Try again"
            fi
              
          done
        }
    
        if [ ! -f "${tikal-paths.tikal-main}" ]; then
          decrypt_tikal_master_key
        fi
      '';
      tikal-main-pub = get-public-file { path = tikal-keys.tikal_main_pub; };
      tikal-main-enc = get-public-file { path = tikal-keys.tikal_main_enc; mode = 600; };
    in
      {
        imports = tikal.prelude.trace tikal-context.modules tikal-context.modules;
        config = {
          environment.etc = tikal.prelude.trace-value {
            ${tikal-paths.relative.tikal-main-pub} = tikal-main-pub;
            ${tikal-paths.relative.tikal-main-enc} = tikal-main-enc;
          };
          boot.initrd = {
            postDeviceCommands = lib.mkAfter ''
              source "${unlock-script}"
            '';
            extraFiles = {
              #tikal-main-pub = tikal-main-pub;
              #tikal-main-enc = tikal-main-enc;
            };
          };
        };
      }
    ;
  in
    { inherit module; }
