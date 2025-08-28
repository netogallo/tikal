{ callPackage, pkgs, lib, tikal-config, ... }:
let
  scope = lib.makeScope pkgs.newScope (self:
    {
      do = self.callPackage ./prelude/do.nix {};
      trace = self.callPackage ./prelude/trace.nix {};
      main = self.callPackage ./prelude/main.nix {};
      log = self.callPackage ./prelude/log.nix { inherit (tikal-config) log-level; };
      template = self.callPackage ./prelude/template.nix {};
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
