{ tikal, tikal-flake-context, pkgs, lib, ... }:
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
  inherit (tikal.prelude) do test debug-print;
  inherit (tikal.sync) nahual-sync-script sync-script sync-script-tests;
  inherit (tikal.template) template;
  inherit (tikal.xonsh) xsh;
  inherit (lib) types mkIf mkOption;
  inherit (tikal.store.lock) get-resource-path hash-key lockfile-name
    lockdir-name lockstore-name;

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
    nahual-sync-script {
      name = "tikal_store_lock";
      description = ''
        This sync script is responsible for creating locked store paths inside the Tikal configuration.
        A locked store path is simply a copy of a regular store path into the public part of the Tikal
        configuration. A store lockfile identifies each of the paths with a unique and stable key.
        The idea is that the output of various, normally impure, derivations can be shared accross
        different machines.
      '';
      vars = { inherit locks lockdir-name lockfile-name lockstore-name; };
      script = { vars, ... }: template ./tikal-store-lock/main.xsh vars;
    }
  ;
  store-lock-tests = { tests, locks, universe, to-nix-tests ? null }: sync-script-tests {
    inherit to-nix-tests;
    vars = {
      inherit lockdir-name lockfile-name lockstore-name;
      locks = to-lock-config locks;
    };
    sync-script = {
      name = "tikal_store_lock_test";
      description = "Test script for store locks";
      script = { vars, ... }: template ./tikal-store-lock/main.xsh vars;
    };
    tests = args@{ vars, ... }:
      ''
      class StoreLockTestCaseBase(SyncTestCaseBase):

        @property
        def input_locks(self):
          return ${vars.locks}

        def get_lock_paths(self, index = None):
          if self.sync_run_count < 1:
            raise Exception("You must call '__run_sync_script__' before attempting to read the resulting lockfile.")

          matches = self.tikal.log.get_matching_logs(message = "Lock Paths")

          if index is None:
            return matches
          else:
            return matches[index]

        def get_written_lock(self, index = 0):
          import json
          lock_paths = self.get_lock_paths()[index]
          lock_file = lock_paths['lock_file']

          with open(lock_file, 'r') as fp:
            return json.load(fp)

      ${tests args}
      ''
    ;
  };
in
  test.with-tests
  {
    inherit __doc__ create-sync-script create-locked-derivations to-lock-config;
    get-resource-path = lib.makeOverridable get-resource-path { lockdir-root = tikal-flake-context.public-dir; };
  }
  {
    tikal.store-lock =
      let
        locks = [
          {
            key = { name = "lock1"; };
            derive = pkgs.writeTextFile { name = "lock1"; text = "lock1"; destination = "/lock1"; };
          }
        ];
      in
        store-lock-tests {
          universe = {
            nahuales = {};
          };
          inherit locks;
          tests = { vars, ... }:
            ''
            class TestStoreLock(StoreLockTestCaseBase):

              def test_lock_derivation(self):
                import json
                from os import path

                self.__run_sync_script__()

                lock_paths = self.get_lock_paths()
                self.assertEqual(1, len(lock_paths))
                lock_store_directory = lock_paths[0]['lock_store_directory']

                written_lock = self.get_written_lock()
                input_locks = ${vars.locks}

                self.assertTrue(len(written_lock) == 1, f"Expected 1 item in the lockfile")

                for uid,input_lock in input_locks.items():

                  self.assertTrue(uid in written_lock, "Lock was not written to store lock file")

                  written_lock_path = written_lock[uid]
                  derive = input_lock.derive

                  self.assertTrue(written_lock_path in derive, f"Expected '{written_lock_path}' to appear in '{derive}'")

                  lock_store_written_path = path.join(lock_store_directory, written_lock_path)
                  self.assertTrue(path.isdir(lock_store_written_path), f"Expected '{lock_store_written_path}' to be a directory.")
            ''
          ;
          to-nix-tests = { results, output, ... }:
            results //
            {
              "Lock output matches key." = { _assert, ... }:
                let
                  test-get-resource-path =
                    get-resource-path
                    {
                      lockdir-root = "${output}/workdir/sync/.tikal/public";
                    }
                  ;
                  check = { key, ... }:
                    _assert.true
                    (lib.pathExists (test-get-resource-path key))
                    ''Could not find the locked store path at "${test-get-resource-path key}" for key "${debug-print key}".''
                  ;
                in
                  _assert.all (map check locks)
              ;
            }
          ;
        };
  }
