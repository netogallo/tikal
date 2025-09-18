{ tikal, pkgs, lib, ... }:
let
  inherit (tikal.prelude) do store-path-to-key;
  inherit (tikal.prelude.python) is-valid-python-identifier store-path-to-python-identifier;
  inherit (tikal.xonsh) xsh;
  inherit (tikal.prelude) test;
  nahual-sync-script =
    {
      name
    , description
    , each-nahual
    }:
    let
      valid-name =
        if is-valid-python-identifier name
        then name
        else throw "The script name must be a valid python module name. Got '${name}'"
      ;
      each-nahual-vars = {
        nahual-name = "_nahual_name_5d1ab2d6";
        nahual-spec = "_nahual_spec_5d1ab2d6";
      };
      each-nahual-text = each-nahual { vars = each-nahual-vars; };
      each-nahual-script = xsh.write-script {
        name = "each.xsh";
        vars = {};
        script = { vars, ... }: with each-nahual-vars; ''
          def __main__(tikal, universe, quine_uid):
            all_nahuales = universe.nahuales
            for ${nahual-name}, ${nahual-spec} in all_nahuales.items():
              tikal.log_info(f"begin (${valid-name}, {quine_uid}, {${nahual-name}})")
              ${each-nahual-text}
              tikal.log_info(f"done (${valid-name}, {quine_uid}, {${nahual-spec}})")
        '';
      };
      uid = store-path-to-key "${each-nahual-script}";
      packages = { universe, ...}:
        let
          main = xsh.write-script {
            name = "main.xsh";
            vars = { inherit universe; };
            script = { vars, ... }: ''

              def __main__(tikal):
                universe = ${vars.universe}
                quine_uid = "${uid}"
                # todo:
                # Check if tikal folder already exits. Skip if so.
                # Otherwise, create the folder
                from ${valid-name} import each
                each.__main__(tikal, universe, quine_uid)
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
  sync-test = xsh.write-packages {
    name = "sync_test";
    packages = {
      sync_test = {
        __init__ = ./sync_test/__init__.py;
      };
    };
  };
in
  test.with-tests
  {
    inherit nahual-sync-script;
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
            sync-test.pythonpath
          ];
          script = ''
            import unittest
            from sync_test import TikalMock

            class TestSync(unittest.TestCase):
          
              def test_runs_sync_script(self):
                import test_sync_script
                test_sync_script.__main__(TikalMock())
            ''
          ;
        }
    ;
  }
