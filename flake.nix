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
        dummy = pkgs.writeScript "tikal" "echo hello tikal!";
      in
        {
          lib = {
            universe = spec: args: {
              apps = {
                sync = (pkgs.callPackage ./lib/sync.nix { universe = args; }).app;
              };
            };
          };
          packages.default = pkgs.writeScript "tikal" "echo hello tikal!"; 
        }
    );
}
