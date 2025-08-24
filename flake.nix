{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    utils.url = "github:numtide/flake-utils";    
  };

  outputs = { self, nixpkgs, utils }:
  let
    inherit (utils.lib) eachDefaultSystem;
    flake = config:
      eachDefaultSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          tikal = pkgs.callPackage ./tikal.nix { inherit nixpkgs system config; };
        in
          {
            packages.default = pkgs.writeScript "tikal" "echo hello tikal!";
          }
          // tikal
      )
    ;
    defaults = {};
  in
    flake defaults
    // {
      override = overrides: flake (defaults // overrides);
    }
  ;
}
