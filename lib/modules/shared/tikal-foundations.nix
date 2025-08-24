{ lib }:
let
  inherit (lib) strings;
  paths = rec {
    # Todo. Allow configuring in universe module
    root = "/etc/tikal";
    system = "${root}/system";
    keys = "${system}/keys";
    tikal-main = "${keys}/id_tikal";
    tikal-main-pub = "${keys}/id_tikal.pub";
    tikal-main-enc = "${keys}/id_tikal.enc";
    store-secrets = "${root}/store-secrets";
  };
  as-relative = _: path:
    if strings.substring 0 5 path == "/etc/"
    then strings.substring 5 (-1) path
    else throw "The tikal folder must reside under '/etc/', found '${path}'."
  ;
  relative-paths = lib.mapAttrs as-relative paths;
in
{
  # Paths is an attribute set containing the final location
  # in the nixos system of important tikal files.
  paths = paths // { relative = relative-paths; };
}
