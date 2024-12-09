{ nixpkgs ? import <nixpkgs> {}, ... }:
  let tikal = import ./bootstrap/default.nix { inherit nixpkgs; };
in
  (tikal.tikal { tests-prop = "tests"; verbose-tests = true; } ./test).tests
