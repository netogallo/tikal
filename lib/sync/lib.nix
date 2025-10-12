{ tikal, pkgs, lib, ... }:
let
  inherit (tikal.prelude) do store-path-to-key;
  inherit (tikal.prelude.python) is-valid-python-identifier store-path-to-python-identifier;
  inherit (tikal.xonsh) xsh;
  inherit (tikal.prelude) test;
  inherit (tikal.prelude.attrs) merge-disjoint;
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
              name = "each_item.xhs";
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
      packages = { universe, ...}:
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
                script_main.__main__(tikal, universe, "${uid-main}")
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
        __init__ = ./sync_test/__init__.py;
      };
      sync_lib = {
        core = ./sync_lib/core.xsh;
      };
    };
  };
in
  test.with-tests
  {
    inherit nahual-sync-script sync-lib;
  }
  {
    tikal.sync =
      let
        universe = {
          nahuales = {
            test-nahual-1 = {};
            test-nahual-2 = {};
          };
        };
        sync-script-args = {
          name = "test_sync_script";
          description = "Sync script for unit testing";
          each-nahual = { vars, ... }: with vars;
            ''
            tikal=${tikal-context}
            nahual_name=${nahual-name}
            test_case = tikal.test_case
            test_case.assertTrue(nahual_name is not None, "Cannot access the nahual name")
            ''
          ;
        };
        packages =
          (nahual-sync-script sync-script-args).packages
          { inherit universe; }
        ;
      in
        xsh.test {
          name = "sync_tests";
          pythonpath = [
            packages.pythonpath
            sync-lib.pythonpath
          ];
          script = ''
            import unittest
            from sync_test import TikalMock

            class TestSync(unittest.TestCase):
          
              def test_runs_sync_script(self):
                import test_sync_script
                test_sync_script.__main__(TikalMock(self))
            ''
          ;
        }
    ;
  }
