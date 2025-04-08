{
  pkgs,
  nixpkgs,
  system
}:
let
  pkgs = import nixpkgs { inherit system; };
  prelude = pkgs.callPackage ./lib/prelude.nix { };
  xonsh = pkgs.callPackage ./lib/xonsh.nix (prelude // { inherit nixpkgs; });
  callPackage = pkgs.newScope (prelude // xonsh // { inherit callPackage nixpkgs pkgs; }); 
  universe =
    spec:
    {
      # The root path of the flake. Should always be ./
      flake-root,
      base-dir ? null
    }:
    let
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
    in
      {
        apps = {
          sync = (callPackage ./lib/sync.nix { universe = instance.config; }).app;
          xonsh = xonsh.xonsh-app;
        };
        nixosModules = nixos.nixos-modules;
      }
  ;
in
{
  lib = {
    inherit universe;
  };
}
