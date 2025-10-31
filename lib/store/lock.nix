{ lib, tikal, ... }:
let
  inherit (tikal.prelude) do trace;
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
    {
      lockdir-path = "${lockdir-root}/${lockdir-name}";
      lockfile-path = "${lockdir-root}/${lockfile-name}";
    }
  ;
  get-resource-path = { lockdir-root }: key:
    let
      inherit (get-root-paths) lockdir-path lockfile-path;
      hashed-key = hash-key key;
      lockfile = builtins.fromJSON (builtins.readFile lockfile-path);
      path-relative = lockfile.${key};
      error = ''
        The key "${trace.debug-print key}" is not available in
        the store lockfile at "${lockfile-path}".
      '';
    in
      if lib.hasAttr key lockfile
      then "${lockdir-path}/${path-relative}"
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
