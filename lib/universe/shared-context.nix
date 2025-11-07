{ lib }:
let
  get-tikal-dirs = { tikal-dir, ... }: {
    inherit tikal-dir;
    private-dir = "${tikal-dir}/private";
    public-dir = "${tikal-dir}/public";
  };
  tikal-user-spec = { user = "tikal"; group = "tikal"; };
  get-config = { to-nahual, context, nahuales }: {
    inherit (get-tikal-dirs context) tikal-dir private-dir public-dir;
    nahuales = lib.mapAttrs (to-nahual context) nahuales;
    tikal-daemon = {
      inherit tikal-user-spec;
    };
  };
  get-nahual-dirs = ctx: name:
    let
      inherit (get-tikal-dirs ctx) private-dir public-dir;
    in
      rec {
        private-root = "${private-dir}/nahuales/${name}";
        public-root = "${public-dir}/nahuales/${name}";
        keys-root = "${private-root}/keys";
        public-keys-root = "${public-root}/keys";
      }
  ;
  to-nahual =
    ctx: name: _value:
    let
      inherit (get-nahual-dirs ctx name)
        private-root
        public-root
        keys-root
        public-keys-root
      ;
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
in
  {
    inherit to-nahual get-config get-tikal-dirs get-nahual-dirs;
  }
