{ tikal, base-dir, shared-context, flake-root, lib, ... }:
let
  inherit (shared-context) get-tikal-dirs get-config get-nahual-dirs to-nahual;
  flake-context = {
    tikal-dir = 
      if base-dir == null
      then "${flake-root}/.tikal"
      else "${flake-root}/${base-dir}/.tikal"
    ;
  };
  config = nahuales:
    get-config
    {
      inherit to-nahual nahuales;
      context = flake-context;
    }
  ;
in
  lib.makeOverridable
  (
    { nahuales }:
    flake-context //
    {
      inherit flake-root;
      # Only the public dir is accesible in the flake's context
      # All data in the private dir is to be used by the sync
      # script to populate the public dir
      inherit (get-tikal-dirs flake-context) public-dir;
      config =
        if builtins.isNull nahuales
        then config
        else config nahuales
      ;
    }
  )
  { nahuales = null; }

