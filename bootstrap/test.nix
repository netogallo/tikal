{ nixpkgs, tikal-meta, prim, config, ... }: { module-meta, ... }:
let
  lib = nixpkgs.lib;

  pretty-print = value:
    if builtins.typeOf value == "set"
    then "{ " + (lib.concatStringsSep ", " (builtins.attrNames value)) + " }"
    else builtins.toString value
  ;

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

        all =
          let
            succ = outcome.success name;
            acc = n: s:
              if n == succ && s == succ
              then succ
              else outcome.error { test = name; message = "Assertion failed"; }
            ;
          in
            checks: lib.foldr acc succ checks
        ;

        eq = v1: v2:
          if v1 == v2
          then outcome.success name
          else outcome.error {
            test = name;
            message = "Expected: ${pretty-print v2}, Got: ${pretty-print v1}";
          }
        ;

        throws = f:
          let
            result = builtins.tryEval f;
          in
            if result.success
            then outcome.error {
              test = name;
              message = "Expected an exception, but got: ${pretty-print result.value}";
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
    
    __functor = _: key: value:
      let
        tests = value.__tests;
        run-test-wrapper = test: run-test { name = test; test = tests.${test}; };
        outcomes = builtins.map run-test-wrapper (builtins.attrNames tests);
        result = lib.foldl (s: t: "${s}\n${t}") "" outcomes; 
        result-drv = nixpkgs.writeTextFile rec {
          name = "${module-meta.name}.${key}.txt";
          text = result;
          destination = "/tikal/tests/${name}";
        };
        apply-tests = res: value:
          if config.verbose-tests
          then builtins.trace res value
          else value
        ;
      in
        if builtins.hasAttr "__tests" value
        then apply-tests result (value // { ${tikal-meta.tests-uid} = result-drv; })
        else value
      ;
  };

  test = {
    __functor = _: mdl:
      let
        tested-mdl = builtins.mapAttrs run-tests mdl;
        get-test-results = _: value:
          if builtins.hasAttr tikal-meta.tests-uid value
          then [ value.${tikal-meta.tests-uid} ]
          else []
        ;
        collected-tests = lib.concatLists (
          lib.mapAttrsToList get-test-results tested-mdl
        );
        tests-drv = nixpkgs.symlinkJoin {
          name = "${module-meta.name}-tests";
          paths = collected-tests;
        };
      in
        tested-mdl // { ${tikal-meta.tests-uid} = tests-drv; }
    ;
  };
in
{
  inherit test;
}
