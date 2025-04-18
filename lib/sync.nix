{ universe, writeScriptBin, docopts, callPackage, ... }:
let
  keys = callPackage ./sync/keys.nix { inherit universe; };
  sync-script = ''
    from docopt import docopt

    doc = """
    Usage:
      sync [--directory=<dir>]
      sync yes

    Optionas:
      --directory=<dir>       The directory to use to store keys and files
    """

    args = docopt(doc)

    for k,v in args.items():
      print(f"{k} = {v}")
  '';
in
  rec {
    package = writeScriptBin "sync" sync-script { sources = [ keys.script ]; };
    app = {
      type = "app";
      program = "${package}/bin/sync";
    };
  }
