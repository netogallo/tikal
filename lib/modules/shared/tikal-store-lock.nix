{ tikal, pkgs, lib, ... }:
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
  inherit (tikal.sync) nahual-sync-script sync-script sync-script-tests;
  inherit (tikal.prelude.template) template;
  inherit (tikal.xonsh) xsh;
  inherit (lib) types mkIf mkOption;
  inherit (tikal.prelude) test;

  lockdir-path = "public/lock";
  lockfile-path = "${lockdir-path}/lockfile.json";
  lockstore-path = "${lockdir-path}/store";
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
  to-lock-entry = { key, derive }:
    let
      hashed-key = hash-key key;
    in
      {
        ${hashed-key} = { inherit derive; };
      }
  ;
  to-lock-config = do [
    map to-lock-entry
    "|>" lib.foldAttrs (arg: state: state // arg) {}
  ];
  create-locked-derivations = args-any:
    let
      args =
        if lib.isAttrs args-any
        then [ args-any ]
        else args-any
      ;
      items = to-lock-config args;
    in
      {
        config.tikal.store-lock.items = items;
      }
  ;
  create-sync-script = locks:
    let
      x = 5;
    in
      nahual-sync-script {
        name = "tikal_store_lock";
        description = ''
          This sync script is responsible for creating locked store paths inside the Tikal configuration.
          A locked store path is simply a copy of a regular store path into the public part of the Tikal
          configuration. A store lockfile identifies each of the paths with a unique and stable key.
          The idea is that the output of various, normally impure, derivations can be shared accross
          different machines.
        '';
        vars = { inherit locks; };
        script = { vars, ... }: template ./tikal-store-lock/main.xsh vars;
      }
  ;
in
  test.with-tests
  {
    inherit __doc__ create-sync-script create-locked-derivations;
  }
  {
    tikal.store-lock = sync-script-tests {
      universe = {
        nahuales = {};
      };
      vars = {
        locks = to-lock-config [
          {
            key = { name = "lock1"; };
            derive = pkgs.writeTextFile { name = "lock1"; text = "lock1"; destination = "/lock1"; };
          }
        ];
      };
      sync-script = {
        name = "tikal_store_lock_test";
        description = "Test script for store locks";
        script = { vars, ... }: template ./tikal-store-lock/main.xsh vars;
      };
      tests = { vars, ... }: with vars;
        ''
        class TestStoreLock(SyncTestCaseBase):

          def test_lock_derivation(self):
            import json

            self.__run_sync_script__()

            lock_paths = self.tikal.log.get_matching_logs(message = "Lock Paths")
            self.assertEqual(1, len(lock_paths))

            lock_file = lock_paths[0]['lock_file']
            with open(lock_file, 'r') as fp:
              written_lock = json.load(fp)
            input_lock = ${locks}

            self.assertTrue(False)
        ''
      ;
    };
  }
