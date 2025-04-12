{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";    
  };

  outputs = { self, nixpkgs, utils }:
  let
    inherit (utils.lib) eachDefaultSystem;
  in
    eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        prelude = pkgs.callPackage ./lib/prelude.nix { };
        xonsh = pkgs.callPackage ./lib/xonsh.nix (prelude // { inherit nixpkgs; });
        callPackage = pkgs.newScope (prelude // xonsh // { inherit callPackage nixpkgs pkgs; }); 
      in
        {
          lib = {
            universe = spec: args: {
              apps = {
                sync = (callPackage ./lib/sync.nix { universe = callPackage spec {}; }).app;
                xonsh = xonsh.xonsh-app;
              };
            };
          };
          packages.default = pkgs.writeScript "tikal" "echo hello tikal!"; 
        }
    );
}
