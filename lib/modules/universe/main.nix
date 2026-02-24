{ flake-context, sync-context, tikal, lib, newScope, ... }:
let
  log = tikal.prelude.log.add-context { file = ./main.nix; };
  nahual-pkgs = self: nahuales:
    let
      log' = log.add-context { function = "nahual-pkgs"; };
      flake-config = log.log-value "flake-context" (flake-context.config nahuales);
      make-pkgs = name: pkg: lib.mapAttrs (make-nahual-pkg pkg) nahuales;
      make-nahual-pkg = pkg: name: nahual:
        let
          nahual-config = {
            flake = flake-config.nahuales.${name};
          };
          package-context = {
            inherit nahual-config;
          };
        in
          self.callPackage pkg package-context
      ;
    in
      lib.mapAttrs
      make-pkgs
      {
        tikal-secrets = ./tikal-secrets.nix;
      }
  ;

  /**
  This is the scope that gets passed as the arguments to the modules
  which define the universe. This module mainly contains libraries
  which are specific to the universe evaluation stage.
  */
  scope = lib.makeScope newScope (self: {
    inherit tikal;
    tikal-foundations = self.callPackage ../shared/tikal-foundations.nix {};
    tikal-log = self.callPackage ../shared/tikal-log.nix {};
    # nahual-pkgs = nahual-pkgs self;
    tikal-store-lock = self.callPackage ./tikal-store-lock.nix {};
    tikal-secrets = self.callPackage ../tikal-secrets.nix {};
    tikal-nixos-context = self.callPackage ../tikal-nixos-context.nix {};
    tikal-flake-context = self.callPackage ../tikal-flake-context.nix {};
    tikal-sync-context = sync-context.config;
  });
in
  scope
