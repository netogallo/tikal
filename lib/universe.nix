{ universe, lib, ... }:
let
  module = lib.evalModules {
    modules = [
      ./universe/members.nix
      universe
    ];
  };
in
  {
    nahuales = {
      names = lib.attrNames module.config.nahuales;
    };
  }
