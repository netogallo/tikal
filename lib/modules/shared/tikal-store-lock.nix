{ tikal, lib, ... }:
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
  inherit (lib) types mkOption;
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
  to-locked-config = { key, derive }:
    let
      hashed-key = hash-key key;
    in
      {
        ${hashed-key} = { inherit derive; };
      }
  ;
  create-locked-derivations = args-any:
    let
      args =
        if lib.isAttrs args-any
        then [ args-any ]
        else args-any
      ;
      items = do [
        args-any
        "$>" map to-locked-config
        "|>" lib.foldAttrs (arg: state: state // arg) {}
      ];
    in
      {
        config.tikal.store-lock.items = items;
      }
  ;
  module = { .. }:
    let
      x = 5;
    in
      {
        options.tikal.store-lock = {
          items = mkOption {
            default = {};
            type = types.attrsOf types.unspecified;
            description = ''
              This option defines the derivations that get locked by the "sync" script. Tikal has the
              ability to describe many "impure" aspects of the universe as a derivation. One notable
              example is "tikal-secrets", which are used to derive cryptographic keys that are then
              encrypted into the nix store. Obviously, one gets a different output every time the
              derivation is run, which in turn can mess up the universe. In this exmaple, if new
              keys are derived upon every update, access might be disrrupted.

              To address this issue, Tikal can "lock" store paths. This consists of defining an
              identifier which is unrelated to a store path. The sync script then checks if this
              identifier is found in the lock store directory of the tikal config. If missing,
              the derivation gets copied and asociated with the lock key. If present, then this
              is ignored.

              The locked store paths can then be commited to a git repository, allowing them to be
              shared as Tikal will always encrypt any secrets that it generates.

              This option allows defining locked store paths. It is an attribute set where keys
              are the unique (and stable) identiifer that are given to a derivation and the value
              is an attribute set with the field "derive" which describes how the value is to
              be generated if missing.

              It is recommended that the "create-locked-derivations" is used to generate a module
              that specifies locked derivations instead of directly setting this option.
            '';
          };
        };
      }
  ;
in
  {
    lib = {
      inherit create-locked-derivations;
    };
    inherit __doc__ module;
  }
