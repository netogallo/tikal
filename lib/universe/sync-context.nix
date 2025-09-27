{ base-dir, lib, shared-context, universe-module }:
let
  inherit (shared-context) get-tikal-dirs get-nahual-dirs get-config to-nahual;
  build-sync-script = state: spec:
    let
      uid = spec.uid;
      context = {
        for-nahual = name: _value:
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
  sync-scripts =
    lib.foldl
      build-sync-script
      {}
      universe-module.config.tikal.sync.scripts
  ;
  to-sync-nahual = ctx: name: value:
    let
      base-ctx = to-nahual ctx name value;
      nahual-sync-scripts-dirs =
        lib.mapAttrs
        (k: s: s.context.for-nahual name value)
        sync-scripts
      ;
      #public = lib.mapAttrs (k: s: s.public) nahual-sync-scripts-dirs;
      #private = lib.mapAttrs (k: s: s.private) nahual-sync-scripts-dirs;
    in
      base-ctx //
      {
        public = base-ctx.public; # // public;
        private = base-ctx.private; # // private;
      }
  ;
  sync-context = {
    tikal-dir =
      if base-dir == null
      then ".tikal"
      else "${base-dir}/.tikal"
    ;
  };
  config =
    get-config
    {
      to-nahual = to-sync-nahual;
      context = get-tikal-dirs sync-context;
      nahuales = universe-module.config.nahuales;
    }
  ;
in
  {
    inherit config;
    # Todo: should the sync scripts be part of the context?
    # inherit sync-scripts;
  }

