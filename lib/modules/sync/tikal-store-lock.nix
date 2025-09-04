{ tikal, tikal-store-lock, ... }:
let
  __doc__ = ''
    This module contains the logic to generate the "sync" script used to
    manage tikal locked store paths.
  '';
  inherit (tikal-store-lock.shared) hash-key;
  inherit (tikal.xonsh) xsh;
  lock-script = { key, drv }:
    let
      uid = hash-key key;
    in
      xsh.write-script {
        name = "lock_${uid}.xsh";
        script = { vars, ... }: ''
        ''
  ;
in
  
