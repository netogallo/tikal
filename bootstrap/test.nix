{ nixpkgs, tikal-meta }: { module-meta }:
let
  lib = nixpkgs.lib;

  outcome = {
    __functor = _: { test, success, message ? null }:
      if success
      then "Test '${test}': Ok"
      else throw "Test '${test}': Error -- ${message}"
    ;

    success = test: outcome { test = test; success = true; };
    error = { test, message }: outcome { test = test; success = false; message = message; };
  };

  run-test = rec {

    test-context = { name, ... }: {
      _assert = {
        __functor = _: value:
          if value
          then outcome.success name
          else outcome.error { test = name; message = "Assertion failed"; }
        ;

        eq = v1: v2:
          if v1 == v2
          then outcome.success name
          else outcome.error {
            test = name;
            message = "Expected: ${builtins.toString v2}, Got: ${builtins.toString v1}";
          }
        ;

        throws = f:
          let
            result = builtins.tryEval f;
          in
            if result.success
            then outcome.error {
              test = name;
              message = "Expected an exception, but got: ${builtins.toString result.value}";
            }
            else outcome.success name
        ;
      };
    };

    __functor = _: { name, test }@spec: test (test-context spec);
  };

  run-tests = {
    __description = ''
      Function to run unit tests for the exported functions of
      the "${module-meta.name}" module.
    '';
    
    __functor = _: value:
      let
        tests = value.__tests;
        run-test-wrapper = test: run-test { name = test; test = tests.${test}; };
        outcomes = builtins.map run-test-wrapper (builtins.attrNames tests);
        result = lib.foldl (s: t: "${s}\n${t}") "" outcomes; 
      in
        if builtins.hasAttr "__tests" value
        then builtins.trace result (value // { ${tikal-meta.tests-uid} = result; })
        else value
      ;
  };

  test = builtins.mapAttrs (key: value: run-tests value);
in
{
  inherit test;
}
