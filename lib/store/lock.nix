{ lib, tikal, ... }:
let
  inherit (tikal.prelude) do debug-print;
  inherit (tikal.prelude.test) with-tests;

  lockfile-name = "tikal_store_lock.json";
  lockdir-name = "tikal_store_lock";
  lockstore-name = "store";
  hash-key = key:
    let
      mapper = name: value: builtins.hashString "sha256" "${name}=${value}";
    in
      do [
        key
        "$>" lib.mapAttrsToList mapper
        "|>" lib.sort (a: b: a > b)
        "|>" lib.concatStrings
        "|>" builtins.hashString "sha256"
      ]
  ;
  get-root-paths = lockdir-root:
    rec {
      lockdir-path = "${lockdir-root}/${lockdir-name}";
      lockfile-path = "${lockdir-path}/${lockfile-name}";
      lockstore-path = "${lockdir-path}/${lockstore-name}";
    }
  ;
  get-resource-path = { lockdir-root }: key:
    let
      inherit (get-root-paths lockdir-root) lockdir-path lockfile-path lockstore-path;
      hashed-key = hash-key key;
      lockfile =
        builtins.fromJSON (
          builtins.unsafeDiscardStringContext (
            builtins.readFile lockfile-path));
      path-relative = lockfile.${hashed-key};
      error = ''
        The key "${debug-print key}" is not available in
        the store lockfile at "${lockfile-path}".
      '';
    in
      if lib.hasAttr hashed-key lockfile
      then "${lockstore-path}/${path-relative}"
      else throw error
  ;
in
  with-tests
  {
    inherit hash-key lockfile-name lockdir-name lockstore-name get-resource-path;
  }
  {
    tikal.store.lock = {
      "The 'hash-key' function is stable:" = { _assert, ... }:
        _assert.eq (hash-key { x = "yes"; y = "no"; }) (hash-key { y = "no"; x = "yes"; })
      ;
      "The 'hash-key' function produces unique hashes" = { _assert, ... }: _assert.all [
        (_assert.neq (hash-key { x = "yes"; }) (hash-key { x = "no"; }))
        (_assert.neq (hash-key { x = "yes"; }) (hash-key { x = "yes"; y = "no"; }))
      ];
    };
  }
