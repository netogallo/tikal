{ self, lib, config, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib)
    mkPerSystemOption;
  inherit (lib) mkIf;
in
  {
    tikal = {
      flake-root = ../.;
      universe-repository = "git+https://github.com/netogallo/tikal.git?ref=feature/with-cryptonix";
      universe = {
        nahuales = {
          test-s1 = {
            network.wireguard.proper-ips = [ "10.0.0.2/32" ];
            nixos = {
              imports = [ ./tikal-test-common.nix ];
            };
          };
          test-s2 = {
            network.wireguard.proper-ips = [ "10.0.0.3/32" ];
            nixos = {
              imports = [ ./tikal-test-common.nix ];
            };
          };
          test-root = {
            network.wireguard = {
              proper-ips = [ "10.0.0.1/32" ];
              proper-endpoint = "192.168.48.254:51666";
            };
            remote-access.openssh.administrator = true;
          };
        };
        network.wireguard.enable = true;
        network.tor.enable = true;
        remote-access.openssh.enable = true;
        universe.id = "tikal-test";
      };
      log-level = 7;
      test-filters = [ { glob = "*"; } ];
      sync = {
        extra-nix-args = "$EXTRA_NIX_ARGS";
      };
    };
  }
