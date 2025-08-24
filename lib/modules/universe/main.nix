{ pkgs, flake-scope, tikal, lib, universe, ... }:
let
  log = tikal.prelude.log.add-context { file = ./main.nix; };
  nahual-pkgs = self: nahuales:
    let
      log' = log.add-context { function = "nahual-pkgs"; };
      flake-context = log.log-value "flake-context" (flake-scope nahuales).flake-context;
      make-pkgs = name: pkg: lib.mapAttrs (make-nahual-pkg pkg) nahuales;
      make-nahual-pkg = pkg: name: nahual:
        let
          nahual-config = {
            flake = flake-context.config.nahuales.${name};
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
  scope = lib.makeScope pkgs.newScope (self: {
    inherit pkgs lib tikal universe;
    tikal-foundations = self.callPackage ../shared/tikal-foundations.nix {};
    tikal-log = self.callPackage ../shared/tikal-log.nix {};
    nahual-pkgs = nahual-pkgs self;
  });
in
  scope
