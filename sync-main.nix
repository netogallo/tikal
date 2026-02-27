{
  nixpkgs,
  lib,
  system,
  universe,
  nixos-rockchip,
  pkgs,
  nix-crypto,
  ...
}@inputs:
let
  scopes = import ./tikal-scope.nix inputs;
  inherit (scopes) universe-scope;
  inherit (universe-scope) tikal lib;
  log = tikal.prelude.log.add-context { file = ./sync-main.nix; };
  full-scope = scopes.full-scope { inherit pkgs nixos-rockchip nix-crypto; };

  # Construct the scope that will be used when
  # evaluating the sync module
  sync-eval-scope = full-scope.overrideScope(self: super: {

    # After computing the universe, the "sync" module needs
    # to be constructed and evaluated.
    sync-module = log.log-value "universe-module" (lib.evalModules {
      modules = [
        ./modules/sync/main.nix
        {
          config._module.args = self.callPackage ./lib/modules/sync/main.nix {};
        }
      ];
    });
    sync = self.callPackage ./lib/sync.nix {};
  });
in
  sync-eval-scope.sync
