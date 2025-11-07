{ tikal, pkgs, lib, callPackage, ... }:
let
  inherit (tikal.prelude) do store-path-to-key;
  inherit (tikal.prelude.python) is-valid-python-identifier store-path-to-python-identifier;
  inherit (tikal.xonsh) xsh;
  inherit (tikal.prelude) test;
  inherit (tikal.prelude.attrs) merge-disjoint map-attrs-with;
  nahual-sync-script =
    {
      name
    , description
    , each-nahual ? null
    , script ? null
    , vars ? {}
    }:
    let
      valid-name =
        if is-valid-python-identifier name
        then name
        else throw "The script name must be a valid python module name. Got '${name}'"
      ;
      each-nahual-vars = {
        nahual-name = "$_nahual_name_5d1ab2d6";
        nahual-spec = "$_nahual_spec_5d1ab2d6";
        tikal-context = "$_tikal_5d1ab2d6";
        tikal-universe = "$_tikal_universe_5d1ab2d6";
      };
      make-user-script = globals: script: { vars, ... }@args':
        let
          args = args' // { vars = merge-disjoint vars globals; };
        in
          script args
      ;
      each-nahual-text =
        let
          script-file =
            xsh.write-script {
              name = "each_item.xsh";
              inherit vars;
              script = make-user-script each-nahual-vars each-nahual;
            }
          ;
        in
          "source ${script-file}"
      ;
      each-nahual-script-main = { ... }:
        if each-nahual == null
        then
          ''
          def __main__(tikal, universe, quine_uid):
            tikal.log_info("${name}: No 'each-nahual' script provided.")
          ''
        else
          with each-nahual-vars;
          ''
          def __main__(tikal, universe, quine_uid):
            all_nahuales = universe.nahuales
            for name, spec in all_nahuales.items():
              ${tikal-context}=tikal
              ${tikal-universe}=universe
              ${nahual-spec}=spec
              ${nahual-name}=name
              tikal.log_info(f"begin ({name}, {quine_uid})")
              ${each-nahual-text}
              ${tikal-context}.log_info(f"done ({name}, {quine_uid})")
          ''
      ;
      each-nahual-script = xsh.write-script {
        name = "each.xsh";
        vars = {};
        script = each-nahual-script-main;
      };
      main-script-text =
        let
          script-file =
            xsh.write-script {
              name = "main_script.xsh";
              inherit vars;
              script = make-user-script each-nahual-vars script;
            }
          ;
        in
          "source ${script-file}"
      ;
      main-script-wrapper-text = { ... }:
        if script == null
        then
          ''
          def __main__(tikal, universe, quine_uid):
            tikal.log_info("${name}: No 'script' provided.")
          ''
        else
          with each-nahual-vars; ''
          def __main__(tikal, universe, quine_uid):
            ${tikal-context}=tikal
            ${tikal-universe}=universe
            tikal.log_info("begin the script execution of '${name}'")
            ${main-script-text}
            tikal.log_info("end the script execution of '${name}'")
          ''
      ;
      main-script = xsh.write-script {
        name = "main_script.xsh";
        vars = {};
        script = main-script-wrapper-text;
      };
      uid-each = store-path-to-key "${each-nahual-script}";
      uid-main = store-path-to-key "${main-script}";
      packages = { universe, ... }:
        let
          main = xsh.write-script {
            name = "main.xsh";
            vars = { inherit universe; };
            script = { vars, ... }: ''

              def __main__(tikal):
                universe = ${vars.universe}
                # todo:
                # Check if tikal folder already exits. Skip if so.
                # Otherwise, create the folder
                from ${valid-name} import each
                each.__main__(tikal, universe, "${uid-each}")

                from ${valid-name} import main_script
                main_script.__main__(tikal, universe, "${uid-main}")
            '';
          };
          __init__ =
            ''
            def __main__(tikal):
              tikal.log_info(f"Running sync hook '${valid-name}'")
              from ${valid-name} import main
              main.__main__(tikal)
            ''
          ;
        in
          xsh.write-packages {
            name = valid-name;
            packages = {
              ${valid-name} = {
                inherit __init__ main;
                each = each-nahual-script;
                main_script = main-script;
              };
            };
          }
      ;
    in
      {
        name = valid-name;
        inherit packages;
      }
  ;
  sync-lib = xsh.write-packages {
    name = "sync_test";
    packages = {
      sync_test = {
        core = ./sync_test/core.xsh;
      };
      sync_lib = {
        core = ./sync_lib/core.xsh;
      };
    };
  };
  sync-script-tests =
    { sync-script
    , tests
    , universe ? {}
    , vars ? {}
    , to-nix-tests ? null
    }:
    let
      universe-instance =
        callPackage
        ../universe.nix
        {
          inherit universe;
          flake-root = ./.;
          base-dir = null;
        }
      ; 
      override-user-script = script-fn:
        let
          script-fn-override = args:
            script-fn (args // { test-vars = args.vars // test-env-vars; })
          ;
        in
          if script-fn == null
          then null
          else
            script-fn-override
      ;
      sync-script-with-overrides =
        map-attrs-with.override
        { defaults = { vars = {}; }; }
        { vars = _: sync-vars: sync-vars // vars; }
        sync-script
      ;
      sync-script-test =
        map-attrs-with
        {
          each-nahual = _: override-user-script;
        }
        sync-script-with-overrides
      ;
      test-vars-prefix = "$_test_var_unique_9tbt923gs";
      test-tikal = "${test-vars-prefix}_tikal";
      test-case = "${test-vars-prefix}_test_case";
      test-context = "${test-vars-prefix}_test_context";
      test-env-vars = { inherit test-case test-tikal test-context; };
      script-builder = nahual-sync-script sync-script-test;
      script = script-builder.packages { universe = universe-instance.config; };
      name = script-builder.name;
      xsh-vars = xsh.to-xsh-vars vars;
      tests-text = tests { vars = xsh-vars.bindings; };
    in
      xsh.test {
        inherit name to-nix-tests;
        pythonpath = [
          script.pythonpath
          sync-lib.pythonpath
        ];
        script = ''
          import unittest
          from sync_test.core import TikalMock

          ${test-tikal} = None
          ${test-case} = None
          ${test-context} = None

          class SyncTestCaseBase(unittest.TestCase):

            def __init__(self, *args, **kwargs):
              super().__init__(*args, **kwargs)
              self.__sync_run_count = 0

            @property
            def tikal(self):
              return self.__tikal

            @property
            def sync_run_count(self):
              return self.__sync_run_count

            def setUp(self):
              self.__tikal = TikalMock()
              ${test-tikal} = self.__tikal
              ${test-case} = self

            def __run_sync_script__(self, test_context = None):
              import ${name} as sync_script
              ${test-context} = test_context
              sync_script.__main__(self.__tikal)
              self.__sync_run_count += 1

          ${xsh-vars.text}
          ${tests-text}
        '';
      }
  ;
in
  test.with-tests
  {
    inherit nahual-sync-script sync-lib sync-script-tests;
  }
  {
    tikal.sync = sync-script-tests {
      universe = {
        nahuales = {
          test-nahual-1 = {};
          test-nahual-2 = {};
        };
      };
      sync-script = {
        name = "test_sync_script";
        description = "Sync script to test running sync scripts";
        each-nahual = { test-vars, ... }: with test-vars;
          ''
          context = ${test-context}
          nahual_name = ${nahual-name}
          context.nahuales.append(nahual_name)
          ''
        ;
      };
      tests = { ... }:
        ''
        from types import SimpleNamespace

        class TestSyncScript(SyncTestCaseBase):

          def test_runs_sync_script(self):
            context = SimpleNamespace()
            context.nahuales = []

            self.__run_sync_script__(test_context = context)
            
            expected = set(["test-nahual-1", "test-nahual-2"])
            self.assertEqual(expected, set(context.nahuales))
        '';
    };
  }
