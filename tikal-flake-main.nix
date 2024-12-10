{ use, nixpkgs, ... }:
let
  tikal-tests = use ./test.nix { };
  tikal-package = use ./bootstrap/default.nix { };
in
  {
    packages = {
      tikal.tests = tikal-tests;
      tikal.package = tikal-package;
    };
    defaultPackage = tikal-tests;
  }

