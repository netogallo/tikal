{
  lib,
  newScope,
  ...
}:
lib.makeScope newScope (self:
  {
    lock = self.callPackage ./store/lock.nix {};
    secrets = self.callPackage ./store/secrets.nix {};
  }
)
