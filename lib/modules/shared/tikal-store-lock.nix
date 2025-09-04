{ tikal, ... }:
let
  __doc__ = ''
  Tikal relies a lot on "impure" derivations. Although theese derivations are discouraged
  as they hinder reproducibility, Tikal only uses them very selectively in places
  where reproducibility is actually not desired.

  One example is the generation of private keys. Tikal relies in the "tikal-secrets.nix"
  module for this task. A script is supplied which is used to generate a key. However,
  instead of writing the key directly to the store (as normally done in regular derivations),
  the key gets encrypted using a public key and the encrypted data is instead written to
  the nix store. The corresponding private key must be made available to the NixOs system
  which uses the key so it can be decrypted on boot and made available.

  However, this means that the derivation is impure, which is undesirable as keys only
  need to be generated once and not re-generated if inputs change (ie. the version
  of openssh used to generate the key). To address this issue, Tikal mantains a copy
  of store paths and a lockfile for theese paths in the public configuration directory.

  This in turn allows using an arbitrary set of identifiers to name a derivation with
  some specific output. If a derivation already exists for those identifiers, it is
  returned as is, otherwise it will be computed and added to the lock file using
  the "sync" script.
  '';
  inherit (tikal.prelude) do;
  lockdir-path = "public/lock";
  lockfile-path = "${lockdir-path}/lockfile.json";
  lockstore-path = "${lockdir-path}/store";
  hash-key = key:
    let
      mapper = name: value: "${name}=${value}";
    in
      do [
        key
        "$>" lib.mapAttrsToList mapper
        "|>" lib.sort (a: b: a > b)
        "|>" lib.hashString "sha256"

      ]
  ;
in
  {
    inherit __doc__ lockdir-path lockfile-path lockstore-path hash-key;
  }
