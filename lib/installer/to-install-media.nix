{
  tikal,
  tikal-config,
  universe,
  lib,
  platform-name,
  platform-spec,
  nixos-rockchip,
  nixpkgs,
  tikal-scopes,
  system,
  ...
}:
let
  inherit (tikal.prelude) do;
  inherit (tikal) prelude;
  build-system = system;
  log = prelude.log.add-context { file = ./to-install-media.nix; };
  tikal-platforms =
    import
    ../modules/nixos/tikal-platforms.nix
    { inherit nixos-rockchip build-system; }
  ;
  top-module = { nahual, pkgs, ... }:
  let
    full-scope = tikal-scopes.full-scope { inherit pkgs; };
    installer-scope = full-scope.overrideScope (self: super: {
      inherit nahual platform-name platform-spec nixos-rockchip build-system;
      args = self.callPackage ../modules/nixos/main-installer.nix {};
    });
    args = {
      inherit tikal-platforms tikal-config;
      inherit (installer-scope.args) tikal platform-name platform-spec tikal-installer;
    };
  in
    {
      imports = [
        ../../modules/installer/main.nix
        platform-spec.installer-module

        # Todo: this is obviously not correct as we are simply
        # including this module that should be provided by the
        # platform module. However, it is tricky as it comes from
        # an external flake and inputs cannot access the
        # values of args.
        tikal-platforms.rockchip.rk3588s-OrangePi5B.sd-image-module
      ];
      config._module.args = args;
    }
  ;
  make-nahual-package = nahual: _:
  let
    nixos = nixpkgs.lib.nixosSystem {
      modules = [
        {
          config = {
            _module.args = { inherit nahual; };
            #nixpkgs.hostPlatform = platform-spec.system;
          };
        }
        top-module
      ];
    };
  in
    {
      "tikal-installer-${nahual}-${platform-name}-sdimage" = nixos.config.system.build.sdImage;
    }
  ;
in
  {
    packages = do [
      lib.mapAttrs make-nahual-package universe.config.nahuales
      "$>" lib.attrValues
      "|>" lib.foldl (s: v: s // v) {}
    ];
  }
