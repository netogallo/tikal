{ config, lib, tikal-store-lock, ... }:
let
  inherit (lib) mkIf mkOption types;
  inherit (tikal-store-lock) create-sync-script to-lock-config;
  store-lock = config.store-lock;
  is-enabled = lib.length store-lock.items > 0;
  sync-script =
    create-sync-script (to-lock-config store-lock.items);
  store-lock-definition = {
    options = {
      key = mkOption { type = types.attrsOf types.str; };
      derive = mkOption { type = types.package; };
    };
  };
in
  {
    options.store-lock = {
      items = mkOption {
        default = [];
        type = types.listOf (types.submodule store-lock-definition);
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

    config = mkIf is-enabled {
      tikal.sync.scripts = [
        sync-script
      ];
    };
  }


