{ universe, writeScriptBin, docopts, ... }:
let
  sync-script = ''
    from docopt import docopt

    doc = """
    Usage: sync [--verbose]
    """

    args = docopt(doc)

    for k,v in args.items():
      print(f"{k} = {v}")
  '';
in
  rec {
    package = writeScriptBin "sync" sync-script;
    app = {
      type = "app";
      program = "${package}/bin/sync";
    };
  }
