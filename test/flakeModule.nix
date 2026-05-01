{ self, lib, config, flake-parts-lib, ... }:
let
  inherit (self.inputs) nixpkgs;
  inherit (flake-parts-lib)
    mkPerSystemOption;
  inherit (lib) mkIf;
in
  {
    config = {
      tikal = {
        flake-root = ../.;
        universe-repository = "git+https://github.com/netogallo/tikal.git?ref=feature/with-cryptonix";
        universe = {
          nahuales = {
            test-s1 = {
              network.wireguard = {
                proper-ips = [ "10.0.0.2/32" ];
              };
              nixos = {
                imports = [ ./tikal-test-common.nix ];
              };
            };
            test-s2 = {

              # Configure as the VPN server
              network.wireguard = {
                forwarding.enable = true;
                proper-ips = [ "10.0.0.0/24" "10.0.0.1/32" ];
                listen-port = 51666;
                proper-endpoint = "test-s2:51666";
                peers.nahuales = [ "test-s1" "test-root" ];
              };
              nixos = {
                imports = [ ./tikal-test-common.nix ];
              };
            };
            test-root = {
              network.wireguard = {
                proper-ips = [ "10.0.0.3/32" ];
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
    };

    options = {
      perSystem = mkPerSystemOption ({ pkgs, system, ... }:
      let
        make-test = import "${nixpkgs}/nixos/tests/make-test-python.nix";
        test-root = _: { imports = [ self.nixosModules.test-root ]; };
        test-s1 = _: { imports = [ self.nixosModules.test-s1 ]; };
        test-s2 = _: { imports = [ self.nixosModules.test-s2 ]; };
      in
        {
          config = {
            checks.tikal = make-test ({ pkgs, ... }: {
              name = "Tikal Checks";
              nodes = {
                inherit test-root test-s1 test-s2;
              };

              testScript = ''
                import time
                def send_tikal_pass(vm):
                  with open(f".tikal/private/nahuales/{vm.name}/keys/id_tikal.pass", 'r') as pw:
                    key = pw.read()


                  vm.wait_for_console_text("booting system configuration")
                  time.sleep(1)
                  vm.send_chars(f"{key}\n\n")

                vpn_clients = [test_s1, test_root]
                all_vms = [test_s2] + vpn_clients

                for vm in all_vms:
                  vm.start()
                  send_tikal_pass(vm)

                for vm in all_vms:
                  vm.wait_for_unit("network.target")


                # Have the VPN clients ping the
                # server to establish a connection
                for vm in vpn_clients:
                  vm.execute("ping -c 5 10.0.0.1")

                # Check that test-root can ssh
                # into the client
                (code, res) = test_root.execute("su tikal-root -c \"ssh -o StrictHostKeyChecking=no tikal-root@10.0.0.2 'hostname'\"")
                assert res.strip() == "test-s1", f"Expected hostname 'test-s1', got {res.strip()} with code {code}"

              '';
            })
            { inherit system pkgs; };
          };
        }
      );
    };
  }
