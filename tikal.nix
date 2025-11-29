{
  nixpkgs,
  system,
  lib,
  nixos-rockchip,
  tikal-flake,
  config ? {}
}@inputs:
let
  tikal-config =
    {
      log-level = 1;
      test-filters = null;
    } //
    config
  ;
  scope-builder = { system }:
    let
      pkgs = import nixpkgs { inherit system; };
      lib' = pkgs.lib;
    in
      lib'.makeScope pkgs.newScope (self:
        {
          inherit nixpkgs pkgs tikal-config;
          tikal = {
            prelude = self.callPackage ./lib/prelude.nix {};
            xonsh = self.callPackage ./lib/xonsh.nix {};
            sync = self.callPackage ./lib/sync/lib.nix {};
            store = self.callPackage ./lib/store.nix {};
            syslog = self.callPackage ./lib/syslog.nix {};
            platforms = self.callPackage ./lib/platforms.nix { inherit nixos-rockchip; };
            hardcoded = self.callPackage ./lib/hardcoded.nix {};
          };
        })
  ;
  scope = lib.makeOverridable scope-builder { inherit system; };
  inherit (scope) callPackage pkgs xonsh;
  log = scope.tikal.prelude.log.add-context { file = ./tikal.nix; };

  universe =
    # The universe definition. This can be annything which
    # can be treated as a nixos module, including (1) path
    # to a nix file (2) attribute set (3) function, among
    # other values.
    spec:
    {
      # The root path of the flake. Should always be ./
      # This is used by the sync script in order to determine
      # what is the root directory of the systems being configured
      # in order to generate the secrets in the right place.
      flake-root,
      base-dir ? null,
      universe-repository ? null
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
      installers =
        callPackage
        ./lib/installer.nix
        {
          inherit universe-repository;
          universe = instance;
          tikal-scope = scope;
        }
      ;
      vms =
        callPackage
        ./lib/vms.nix
        {
          universe = instance;
          inherit (nixos) nixos-modules;
          inherit tikal-flake;
        }
      ;
    in
      {
        apps =
          {
            sync = (sync-scope.callPackage ./lib/sync.nix { }).app;
            xonsh = xonsh.xonsh-app;
            inherit (installers) installers;
            inherit (vms) vms;
          }
        ;
        nixosModules = log.log-value "Nixos Modules" nixos.nixos-modules;
      }
  ;
in
log.log-info "done" {
  lib = {
    inherit universe;
    inherit (scope) tikal;
  };
}
