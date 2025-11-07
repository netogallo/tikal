{ universe, universe-module, docopts, tikal, lib, callPackage, ... }:
let
  inherit (tikal.prelude) do;
  inherit (tikal.xonsh) xsh;
  inherit (tikal.sync) sync-lib;
  foundations = callPackage ./sync/foundations.nix { };
  #core = callPackage ./sync/core.nix { };
  keys = callPackage ./sync/keys.nix { };
  to-sync-script-module = { name, packages }:
    let
      package-instance = packages { inherit universe; };
    in
      {
        inherit name;
        value = package-instance.pythonpath;
      }
  ;
  make-sync-packages-imports = names:
    let
      mk-import = name: ''
        tikal.log_info("Running sync module '${name}'")
        import ${name}
        ${name}.__main__(tikal)
      '';
    in
      lib.concatStringsSep "\n" (lib.map mk-import names)
  ;
  make-sync-scripts = packages:
    let
      package-names = lib.attrNames packages;
      package-imports = make-sync-packages-imports package-names;
      package-paths = lib.attrValues packages;
    in
      {
        inherit package-names package-imports package-paths;
      }
  ;
  modules-sync-scripts = do [
      modules-sync.scripts
      "$>" lib.map to-sync-script-module
      "|>" lib.listToAttrs
      "|>" make-sync-scripts
  ];

  modules-sync = universe-module.module.config.tikal.sync;
  # modules-sync-scripts = "${modules-sync-scripts}";
  sync-script = ''
    from docopt import docopt
    from sync_lib.core import Tikal

    doc = """
    Usage:
      sync [--verbose] [--passwords <passwords-file>]

    Options:
      --verbose                            The loglevel used by sync
      --passwords <passwords-file>         Use passwords from the supplied file instead of randomly generated ones.
    """

    args = docopt(doc)

    print("Sync script called with flags:")
    for k,v in args.items():
      print(f"{k} = {v}")

    if args["--verbose"]:
      loglevel = 5
    else:
      loglevel = 0

    if args["--passwords"]:
      passwords = open_passwords(args["--passwords"])
    else:
      passwords = None

    tikal = Tikal(
      loglevel = loglevel,
      passwords = passwords
    )

    init_foundations(tikal)
    init_keys(tikal)

    ${modules-sync-scripts.package-imports}
  '';
in
  rec {
    package =
      xsh.write-script-bin {
        name = "sync";
        script = sync-script;
        sources = [
          foundations.script
          keys.script
          #core.script
        ];
        pythonpath =
          [ sync-lib.pythonpath
          ]
          ++ modules-sync-scripts.package-paths
        ;
      }
    ;
    app = {
      type = "app";
      program = "${package}/bin/sync";
    };
  }
