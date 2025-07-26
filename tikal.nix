{
  nixpkgs,
  system,
  lib
}:
let
  scope = lib.makeScope pkgs.newScope (self:
    {
      pkgs = import nixpkgs { inherit system; };
      inherit nixpkgs;
      tikal = {
        prelude = self.callPackage ./lib/prelude.nix {};
        xonsh = self.callPackage ./lib/xonsh.nix {};
        sync = self.callPackage ./lib/sync/lib.nix {};
      };
    }
  );
  inherit (scope) callPackage pkgs xonsh;

  universe =
    spec:
    {
      # The root path of the flake. Should always be ./
      # This is used by the sync script in order to determine
      # what is the root directory of the systems being configured
      # in order to generate the secrets in the right place.
      flake-root,
      base-dir ? null
    }:
    let
      # The "universe.nix" module is responsible for evaluating the
      # module that defines a tikal universe. A nixos universe is
      # configured like a nixos module. However, rather than defining
      # the configuration of a single system, it defines the configuration
      # of multiple systems.
      instance =
        callPackage
        ./lib/universe.nix
        {
          inherit flake-root base-dir;
          universe = spec;
        }
      ;
      nixos =
        callPackage
        ./lib/nixos.nix
        {
          universe = instance;
        }
      ;
      sync-scope = lib.makeScope scope.newScope (self: {
          universe = instance.config;
          universe-module = instance.universe-module;
        }
      );
    in
      {
        apps = {
          sync = (sync-scope.callPackage ./lib/sync.nix { }).app;
          xonsh = xonsh.xonsh-app;
        };
        nixosModules = scope.tikal.prelude.trace nixos.nixos-modules nixos.nixos-modules;
      }
  ;
in
{
  lib = {
    inherit universe;
  };
}
