{ universe, writeScriptBin, docopts, callPackage, ... }:
let
  core = callPackage ./sync/core.nix { inherit universe; };
  keys = callPackage ./sync/keys.nix { inherit universe; };
  sync-script = ''
    from docopt import docopt

    doc = """
    Usage:
      sync [--directory=<dir>]

    Options:
      --directory=<dir>       The directory to use to store keys and files
    """

    args = docopt(doc)
    tikal = Tikal(
      directory = args["--directory"]
    )

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
          sources = [ keys.script core.script ];
        }
    ;
    app = {
      type = "app";
      program = "${package}/bin/sync";
    };
  }
