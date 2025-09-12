{ callPackage, pkgs, lib, tikal-config, ... }:
let
  scope = lib.makeScope pkgs.newScope (self:
    {
      do = self.callPackage ./prelude/do.nix {};
      trace = self.callPackage ./prelude/trace.nix {};
      main = self.callPackage ./prelude/main.nix {};
      log = self.callPackage ./prelude/log.nix { inherit (tikal-config) log-level; };
      template = self.callPackage ./prelude/template.nix {};
      python = self.callPackage ./prelude/python.nix {};
      string = self.callPackage ./prelude/string.nix {};
      godel = self.callPackage ./prelude/godel.nix {};
      match = self.callPackage ./prelude/match.nix {};
      test = self.callPackage ./prelude/test.nix { inherit (tikal-config) test-filters; };
      list = self.callPackage ./prelude/list.nix {};
      path = self.callPackage ./prelude/path.nix {};
    }
  );
in
  scope
  //
  scope.main
  //
  {
    inherit (scope.do) do;
    inherit (scope.trace) trace trace-value debug-print;
  }
