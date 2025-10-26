{
  lib,
  newScope,
  ...
}:
lib.makeScope newScope (self:
  {
    lock = self.callPackage ./store/lock.nix {};
  }
)
