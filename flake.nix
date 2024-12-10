{
  inputs = {
    systems.url = "github:nix-systems/x86_64-linux";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs = { self, nixpkgs-stable, utils, ... }:
    let
      inherit (utils.lib) eachDefaultSystem;
      mk-context = system:
        let
          nixpkgs = import nixpkgs-stable { inherit system; };
          context = {
            inherit nixpkgs system;
            use = nixpkgs.newScope context;
          };
        in
          context
      ;
      mk-outputs = system: import ./tikal-flake-main.nix (mk-context system);
      packages = eachDefaultSystem mk-outputs;
      each-default-system = fn:
        let
          tikal-context = system: {
            inherit system;
            tikal = packages.packages.${system}.tikal.package;
          };
          run = system: fn (tikal-context system);
        in
          eachDefaultSystem run
      ;
      exports = {
        inherit each-default-system;
      };
    in
    packages // exports
  ;
}

