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
        tikal = pkgs.callPackage ./tikal.nix { inherit nixpkgs system; };
      in
        {
          packages.default = pkgs.writeScript "tikal" "echo hello tikal!";
        } // tikal
    )
  ;
}
