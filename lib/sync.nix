{ universe, writeScriptBin, docopts, callPackage, ... }:
let
  foundations = callPackage ./sync/foundations.nix { inherit universe; };
  core = callPackage ./sync/core.nix { inherit universe; };
  keys = callPackage ./sync/keys.nix { inherit universe; };
  sync-script = ''
    from docopt import docopt

    doc = """
    Usage:
      sync [--verbose]

    Options:
      --verbose               The loglevel used by sync
    """

    args = docopt(doc)

    if args["--verbose"]:
      loglevel = 5
    else:
      loglevel = 0

    tikal = Tikal(
      loglevel = loglevel
    )

    init_foundations(tikal)
    init_keys(tikal)

    for k,v in args.items():
      print(f"{k} = {v}")
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
