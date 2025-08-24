{ tikal, pkgs }:
let
  inherit (tikal) xonsh;
  logger = xonsh.writeScriptBin
    "tikal-log"
    ''
    from docopt import docopt
    import os
    progname = os.path.basename(__file__)

    doc = f"""
    Usage:
      {progname} [--tag=tag...] [-w] [-e] [-d] <message>...

    Options:
      -e --error                         Flag log as error
      -w --warning                       Flag log as warning
      -d --debug                         Flag log as debug
      --tag=tag                          Tag to allow groupping of logs (may be repeated)
      <message>                          The message that will be logged
    """
    args = docopt(doc)

    if args["--error"]:
      level = 0
    elif args["--warning"]:
      level = 1
    elif args["--debug"]:
      level = 7
    else:
      level = 6

    message = " ".join(args['<message>'])
    tags = ",".join(args["--tag"])
    log = f"[{tags}] {message}"

    ${pkgs.util-linux}/bin/logger -t tikal -p f"{level}" f"{log}"
    echo f"tikal: level={level} {log}"
    ''
  ;
in
  {
    inherit logger;
    log = "${logger}/bin/tikal-log";
  }
