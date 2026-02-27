{
  universe,
  sync-module,
  docopts,
  tikal,
  lib,
  pkgs,
  callPackage,
  ...
}:
let
  inherit (tikal.prelude) do;
  inherit (tikal.xonsh) xsh;
  inherit (tikal.sync) sync-lib;
  inherit (tikal) crypto;
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

  modules-sync = sync-module.config.sync;
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

    print("The pem is ${crypto.lib.dummy}")
  '';
  tikal-sync-package =
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
  tikal-sync-nix-crypto-package =
    pkgs.writeShellScriptBin
    "sync"
    "${crypto.packages.nix-crypto-tikal}/bin/nix run .#tikal-sync-nix-crypto"
  ;
in
  rec {
    packages = {
      inherit tikal-sync-package tikal-sync-nix-crypto-package;
    };
    apps = {
      tikal-sync = {
        type = "app";
        program = "${packages.tikal-sync-nix-crypto-package}/bin/sync";
      };
      tikal-sync-nix-crypto = {
        type = "app";
        program = "${packages.tikal-sync-package}/bin/sync";
      };
    };
  }
