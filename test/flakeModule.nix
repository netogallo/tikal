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
            nixos = {
              imports = [ ./tikal-test-common.nix ];
            };
          };
          test-s2 = {
            nixos = {
              imports = [ ./tikal-test-common.nix ];
            };
          };
          test-root = {
            remote-access.openssh.administrator = true;
          };
        };
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
