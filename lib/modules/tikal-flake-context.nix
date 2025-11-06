# This file contains constants related to the flake where a tikal universe
# is defined. To create a tikal-universe flake, one defines the universe
# and then uses the sync script to generate the universe's specific files.
# These get placed into a configuration directory which becomes part of the
# flake. This module is used to refer to items in the config directory of
# the flake.
{ lib, tikal, flake-context, ... }:
let
  inherit (tikal.prelude.path) assert-path;
  _legacy-nahual-flake-config = nahual:
    # Todo: terrible API, need to re-implement
    let
      config = flake-context.config { ${nahual} = {}; };
    in
      config.nahuales.${nahual}
  ;
  tikal-flake-keys = { nahual }:
    let
      keys = (_legacy-nahual-flake-config nahual).public.tikal-keys;
      check = assert-path.override {
        is-file = true; 
        error = { path-as-string, ... }: "The key at '${path-as-string}' for the nahual '${nahual}' could not be found. Did you run 'sync' and 'git add .'";
      };
    in
      lib.mapAttrs check { tikal-public-key = keys.tikal_main_pub; }
  ;
  tikal-public-key = args: (tikal-flake-keys args).tikal-public-key;
in
{
  tikal-secrets = {
    inherit tikal-public-key;
  };
}
