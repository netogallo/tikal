{ universe, universe-module, docopts, tikal, lib, callPackage, ... }:
let
  inherit (tikal.prelude) do;
  inherit (tikal.xonsh) writeScriptBin;
  foundations = callPackage ./sync/foundations.nix { };
  core = callPackage ./sync/core.nix { };
  keys = callPackage ./sync/keys.nix { };
  modules-sync-scripts = do [
      modules-sync.scripts
      "$>" lib.map (script: script.text { inherit universe; })
      "|>" lib.concatStringsSep "\n"
  ];
  modules-sync = universe-module.module.config.tikal.sync;
  # modules-sync-scripts = "${modules-sync-scripts}";
  sync-script = ''
    from docopt import docopt

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

    ${modules-sync-scripts}
  '';
in
  rec {
    package =
      writeScriptBin
        "sync"
        sync-script
        {
          sources = [
            foundations.script
            keys.script
            core.script
          ];
        }
    ;
    app = {
      type = "app";
      program = "${package}/bin/sync";
    };
  }
