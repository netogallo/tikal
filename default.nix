{
  fetchzip ? (import <nixpkgs> {}).fetchzip,
  nixpkgs ? import (
    fetchzip {
      url = "https://github.com/NixOS/nixpkgs/archive/c3d4ac725177c030b1e289015989da2ad9d56af0.zip";
      hash = "sha256-sqLwJcHYeWLOeP/XoLwAtYjr01TISlkOfz+NG82pbdg=";
    }
  ) {}
}:
let tikal = rec {
  inherit tikal nixpkgs;
  callPackage = nixpkgs.newScope { inherit tikal; };
  utils = callPackage ./utils/default.nix {};
  users = callPackage ./users/default.nix {};
  };
in
tikal
