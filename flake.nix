{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    utils.url = "github:numtide/flake-utils";    
    nixos-rockchip.url = "github:netogallo/nixos-rockchip/feature/ornagepi5b-updates";
  };

  outputs = { self, nixpkgs, utils, nixos-rockchip }:
  let
    inherit (utils.lib) eachDefaultSystem;
    flake = config:
      eachDefaultSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          tikal =
            pkgs.callPackage
            ./tikal.nix
            {
              inherit nixpkgs system config nixos-rockchip;
              tikal-flake = self;
            };
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
