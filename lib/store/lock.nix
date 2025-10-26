{ lib, tikal, ... }:
let
  inherit (tikal.prelude) do;
  inherit (tikal.prelude.test) with-tests;
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
in
  with-tests
  {
    inherit hash-key;
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
