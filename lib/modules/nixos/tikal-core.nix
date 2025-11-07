{
  get-public-file,
  tikal,
  nahual,
  nahual-modules,
  nahual-config,
  universe,
  pkgs,
  lib,
  callPackage,
  ...
}:
let
  pkgs' = pkgs;
  lib' = lib;
  log = tikal.prelude.log.add-context { file = ./tikal-core.nix; inherit nahual; };
  inherit (tikal.prelude.template) template;
  module = { lib, pkgs, ... }:
    let
      core-scope = lib'.makeScope pkgs'.newScope (self: {
        inherit pkgs lib tikal nahual nahual-config nahual-modules universe;
        tikal-foundations = self.callPackage ../shared/tikal-foundations.nix {};
        tikal-context = self.callPackage ./tikal-context.nix {};
        tikal-log = self.callPackage ../shared/tikal-log.nix {};
        #tikal-secrets = self.callPackage ../universe/tikal-secrets.nix {};
        tikal-meta = self.callPackage ./tikal-meta.nix {};
      });
      inherit (core-scope) tikal-log tikal-context tikal-foundations;
      flake-attrs = universe.flake;
      config = universe.config;
      tikal-keys = nahual-config.public.tikal-keys;
      tikal-paths = tikal-foundations.paths;
      unlock-script =
        pkgs.writeScript
        "unlock"
        (
          template
          ./unlock.sh
          {
            inherit tikal-main-enc tikal-paths;
            age = "${pkgs.age}/bin/age";
            expect = "${pkgs.expect}/bin/expect";
          }
        )
      ;
      tikal-main-pub = get-public-file { path = tikal-keys.tikal_main_pub; };
      tikal-main-enc = get-public-file { path = tikal-keys.tikal_main_enc; mode = 600; };
    in
      {
        imports =
          with core-scope;
          [ tikal-meta.module
          ]
          ++ log.log-value "tikal context modules" tikal-context.modules
        ;
        config = {
          environment.etc = log.log-value "secret keys" {
            ${tikal-paths.relative.tikal-main-pub} = tikal-main-pub;
            ${tikal-paths.relative.tikal-main-enc} = tikal-main-enc;
          };
          boot.initrd = {
            postDeviceCommands = lib.mkAfter ''
              source ${unlock-script}
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
