{ nixpkgs, tikal-meta }: { module-meta }:
let
  lib = nixpkgs.lib;

  run-test = rec {

    test-context = { name, ... }: {
      _assert = value:
        if value
        then "${name}: Passed"
        else throw "${name}: Failed"
      ;
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
