{...}:
  let tikal = import ./bootstrap/default.nix { nixpkgs = import <nixpkgs> {}; };
in
(tikal.tikal { tests-prop = "tests"; verbose-tests = true; } ./test).tests
