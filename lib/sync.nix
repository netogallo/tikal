{ universe, writeScript, docopts, ... }:
let
  sync-script = ''
    set -e
    echo "entering"
    args="$(${docopts}/bin/docopts -h - : "$@" <<EOF
    Usage: sync [options]

    Options:
      --help        Show help
      --version     Print the program's version

    ----
    sync 0.1
    EOF
    )"

    echo "''${args[@]}"
    eval "''${args[@]}"
    echo "this is sync"
  '';
in
  rec {
    package = writeScript "sync" sync-script;
    app = {
      type = "app";
      program = "${package}";
    };
  }
