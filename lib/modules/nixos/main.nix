{
  lib,
  newScope,
  tikal,
  universe,
  nahual,
  tikal,
  ...
}:
let
  log = tikal.prelude.log.add-context { file = ./main.nix; };
in
  log.log-function-call "tikal-module-args" lib.makeScope newScope (self: {
    inherit tikal universe nahual;
    tikal-foundations = self.callPackage ../shared/tikal-foundations.nix {};
    tikal-store-lock = self.callPackage ../shared/tikal-store-lock.nix {};
    tikal-secrets = self.callPackage ../tikal-secrets.nix {};
    tikal-nixos-context = self.callPackage ../tikal-nixos-context.nix {};
    tikal-flake-context = self.callPackage ../tikal-flake-context.nix {};
    tikal-nixos = self.callPackage ./tikal-nixos.nix {};
    tikal-platforms = self.callPackage ./tikal-platforms/platforms.nix {};
  })
