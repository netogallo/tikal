{
  system,
  tikal,
  lib,
  newScope,
  nixos-rockchip,
  callPackage,
  ...
}@inputs:
let
  inherit (tikal.prelude) do;
  platforms = lib.evalModules {
    modules = [
      ./platforms/main.nix
      {
        config._module.args = inputs;
      }
    ];
  };
  to-installer-packages = platform-name: platform-spec:
    let
      images =
        callPackage
        ./installer/to-install-media.nix
        {
          inherit platform-name platform-spec nixos-rockchip;
        }
      ;
    in
    {
      inherit (images) packages;
    }
  ;
in
  do [
    lib.mapAttrs to-installer-packages platforms.config.platforms
    "$>" lib.attrValues
    "|>" lib.foldAttrs (item: acc: acc // item) {}
  ]
