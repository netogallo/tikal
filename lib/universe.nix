{ universe, lib, flake-root, base-dir, ... }:
let
  module = lib.evalModules {
    modules = [
      ./universe/members.nix
      universe
    ];
  };
  tikal-dir =
    if base-dir == null
    then ".tikal"
    else "${base-dir}/.tikal";
  private-dir = "${tikal-dir}/private";
  public-dir = "${tikal-dir}/public";
  to-nahual = name: value:
    let
      private-root = "${private-dir}/${name}";
      public-root = "${public-dir}/${name}";
      keys-root = "${private-root}/keys";
      public-keys-root = "${public-root}/keys";
      public = {
        root = public-root;
        tikal-keys = {
          root = public-keys-root;
          tikal_main_enc = "${public-keys-root}/id_tikal.enc";
          tikal_main_pub = "${public-keys-root}/id_tikal.pub";
        };
      };
      private = {
        root = private-root;
        tikal-keys = {
          root = keys-root;
          tikal_main = "${keys-root}/id_tikal";
          tikal_main_pass = "${keys-root}/id_tikal.pass";
        };
      };
    in
      {
        inherit private public;
      }
  ;
  tikal-user-spec = { user = "tikal"; group = "tikal"; };
in
  {
    config = {
      inherit tikal-dir private-dir public-dir;
      nahuales = lib.mapAttrs to-nahual module.config.nahuales;
      tikal-daemon = {
        inherit tikal-user-spec;
      };
    };
    flake = {
      inherit flake-root;
      # Only the public dir is accesible in the flake's context
      # All data in the private dir is to be used by the sync
      # script to populate the public dir
      public-dir = "${flake-root}/${public-dir}";
    };
  }
