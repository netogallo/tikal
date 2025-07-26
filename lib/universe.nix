{ universe, lib, flake-root, base-dir, callPackage, tikal, pkgs, ... }:
let
  module = lib.evalModules {
    modules = [
      ./universe/members.nix
      ../modules/tikal-main.nix
      universe
    ];
    args = {
      inherit tikal pkgs;
    };
  };
  sync-context = {
    tikal-dir =
      if base-dir == null
      then ".tikal"
      else "${base-dir}/.tikal"
    ;
  };
  flake-context = {
    tikal-dir = 
      if base-dir == null
      then "${flake-root}/.tikal"
      else "${flake-root}/${base-dir}/.tikal"
    ;
  };
  get-tikal-dirs = { tikal-dir }: {
    inherit tikal-dir;
    private-dir = "${tikal-dir}/private";
    public-dir = "${tikal-dir}/public";
  };
  get-nahual-dirs = ctx: name:
    let
      inherit (get-tikal-dirs ctx) private-dir public-dir;
    in
      rec {
        private-root = "${private-dir}/${name}";
        public-root = "${public-dir}/${name}";
        keys-root = "${private-root}/keys";
        public-keys-root = "${public-root}/keys";
      }
  ;
  to-nahual =
    ctx: name: value:
    let
      inherit (get-nahual-dirs ctx name)
        private-root
        public-root
        keys-root
        public-keys-root
      ;
      nahual-sync-scripts-dirs =
        lib.mapAttrs
        (k: s: s.context.for-nahual name value)
        sync-scripts
      ;
      public = {
        root = public-root;
        tikal-keys = {
          root = public-keys-root;
          tikal_main_enc = "${public-keys-root}/id_tikal.enc";
          tikal_main_pub = "${public-keys-root}/id_tikal.pub";
        };
      } // lib.mapAttrs (k: s: s.public) nahual-sync-scripts-dirs;
      private = {
        root = private-root;
        tikal-keys = {
          root = keys-root;
          tikal_main = "${keys-root}/id_tikal";
          tikal_main_pass = "${keys-root}/id_tikal.pass";
        };
      } // lib.mapAttrs (k: s: s.private) nahual-sync-scripts-dirs;
    in
      {
        inherit private public;
      }
  ;
  build-sync-script = state: spec:
    let
      uid = spec.uid;
      context = {
        for-nahual = name: value:
          let
            inherit (get-nahual-dirs sync-context name)
              public-root
              private-root
            ;
          in
            {
              public = {
                root = "${public-root}/${uid}";
              };
              private = {
                root = "${private-root}/${uid}";
              };
            }
        ;
      };
    in
      state // { ${uid} = { inherit context spec; }; }
  ;
  sync-scripts = lib.foldl build-sync-script {} module.config.tikal.sync.scripts;
  tikal-user-spec = { user = "tikal"; group = "tikal"; };
  universe-module = {
    inherit module sync-scripts;
  };
  get-config =
    context:
    {
      inherit (get-tikal-dirs context) tikal-dir private-dir public-dir;
      nahuales = lib.mapAttrs (to-nahual context) module.config.nahuales;
      tikal-daemon = {
        inherit tikal-user-spec;
      };
    }
  ;
in
  {
    # Config is meant to be a static representation of
    # the nixos universe. Its main objective is to be json
    # serializable so it can be embeded into sync scripts
    config = get-config sync-context;
    # Set which contains the universe module along
    # with functions and attribtues to derive attributes
    # from the module
    inherit universe-module;

    # flake contains all the attributes that are to be used
    # by the flake when building the set of nahuales after
    # sync has been run.
    flake = {
      inherit flake-root;
      inherit (get-tikal-dirs flake-context) public-dir;
      # Only the public dir is accesible in the flake's context
      # All data in the private dir is to be used by the sync
      # script to populate the public dir
      config = get-config flake-context;
    };
  }
