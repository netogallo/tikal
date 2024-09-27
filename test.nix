{}:
  let tikal = import ./bootstrap/default.nix { nixpkgs = import <nixpkgs> {}; };
in
(tikal.tikal {} ./demo ).Tikal.Test.value
