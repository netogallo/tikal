{ lib, match, trace, log, test-filters }:
let
  logger = log.add-context { file = ./test.nix; };
  inherit (lib) strings;
  glob-to-re = strings.replace [ "." "*" ] [ "\\." ".*" ];
  match-by-re = re: str: strings.match re str != null;
  process-filter = filter:
    match filter [
      match.is-function (f: f)
      match.is-string (s: strings.hasInfix s)
      ({ glob }: match-by-re (glob-to-re glob))
      match.otherwise (expr:
        trace.throw-print
        {
          inherit expr;
        }
        ''
          The value:

            {expr}

          is not supported as a test filter.
        ''
      )
    ]
  ;
  filters = map process-filter test-filters;

  # defined here as this module uses the function
  # and test should avoid having too much dependencies
  # as it allows other modules to be tested.
  fold-attrs-recursive-impl = path: acc: initial: attrs:
    let
      this-acc = key: state:
        let
          value = attrs.${key};
          full-key = path ++ [key];
        in
          if lib.isAttrs value
          then fold-attrs-recursive-impl full-key acc state value
          else acc state full-key value
      ;
    in
      lib.fold this-acc initial (lib.attrNames attrs)
  ;
  fold-attrs-recursive = fold-attrs-recursive-impl [];

  are-tests-enabled = test-filters != null && lib.length test-filters > 0;

  _assert = { name }:
    let
      run = outcome: message:
        if outcome
        then {
          success = true;
          message = ''
            Test "${name}"
              Result: Ok
          '';
        }
        else {
          success = false;
          message = ''
            Test "${name}"
              Result: Fail
              Message:
                ${message}
          '';
        }
      ;
    in
      {
        __functor: self: test: run test "Expeted expression to be 'true'.";
        eq = a: b: run (a == b) "Expected '${trace.debug-print a}', got '${trace.debug-print b}'";
      }
  ;
  test-context = name: {
    _assert = _assert { inherit name; };
  };
  run-test = { name, test }:
    match (test (test-context name)) [
      ({ success, message }@result: result)
      match.otherwise (result:
        trace.throw-print
        {
          inherit result;
        }
        ''
          Tikal tests must return an assertion. Use the "assert" value
          passed to the test as argument to perform assertions.

          Test: ${name}
          Result: {result}
        ''
      )
    ]
  ;
  with-tests-enabled = module: tests:
    let
      test-acc = state: key: test:
        let
          test-name = strings.concatStringsSep "." key;
          has-match = lib.any (f: f test-name) filters; 
        in
          if has-match
          then state ++ [ { name = test-name; inherit test; } ]
          else state
      ;
      test-list = fold-attrs-recursive test-acc [] tests;
      test-results = map run-test test-list;
      outcome = lib.all (r: r.success) test-results;
      outcome-msg = lib.concatStringsSep "\n\n" (map (r: r.message) test-results);
    in
      if outcome
      then logger.log-debug outcome-msg module
      else throw outcome-msg
  ;

  with-tests = module: tests:
    if are-test-enabled
    then with-tests-enabled module tests
    else module
  ;
in
  {
    inherit fold-attrs-recursive with-tests;
  }
