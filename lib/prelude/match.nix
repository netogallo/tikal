{ lib, trace, godel, ... }:
let
  inherit (godel) types;
  apply-args = fn: args:
    let
      fn-args-spec = builtins.functionArgs fn;
      discard-name = "$$$$attribute_name_that_never_exists_dah4239f43h3923f$$$$";
      mapper = name: optional: 
        if lib.hasAttr name args
        then { inherit name; value = args.${name}; }
        else if optional
        then { name = discard-name; value = null; }
        else throw "The required argument ${name} is missing."
      ;
      fn-args =
        lib.removeAttrs
        (lib.mapAttrs' mapper fn-args-spec)
        [ discard-name ]
      ;
    in
      if lib.length (lib.attrNames fn-args-spec) > 0
      then builtins.tryEval (fn args)
      else throw ''
        Invalid expresion found on match statement. All match
        functions must have explicit attributes as parameters.
        To introduce a 'catch-all' function use the
        'match.otherwise' semantic operator followed by the
        'cath-all' function.
      ''
  ;
  semantic-op-fn-arags = fn: godel.semantic-op {
    name = "match set pattern";
    argc = 0;
    op = expr: apply-args fn expr;
  };
  lift-to-semantic-op = value:
    let
      fn-args = builtins.functionArgs value;
    in
      if lib.isFunction value && lib.length fn-args > 0
      then semantic-op-fn-args value
      else
        trace.throw-print
        {
          inherit value;
        }
        ''
          There is an error in the "match" statement. The value:

            {value}
  
          Was found in an unexpected location. Make sure that
          all cases have the necessary arguments. Furthermore
          note that only the following standalone patterns are
          supported:
            - function with explicit arguments
        ''
  ;
  godel-reduce-args = {
    inherit lift-to-semantic-op;
  };
  is-pattern = cond: handler: expr:
    if cond expr
    then { success = true; value = handler expr; }
    else { success = false; value = null; }
  ;
  is-function = godel.semantic-op {
    name = "match function";
    argc = 1;
    op = is-pattern lib.isFunction;
  };
  is-string = godel.semantic-op {
    name = "match string";
    argc = 1;
    op = is-pattern lib.isString;
  };
  otherwise = godel.semantic-op {
    name = "otherwise";
    argc = 1;
    op = fn: expr: { success = true; value = fn expr; };
  };
  match = expr: cases:
    let
      expressions = godel.reduce godel-reduce-args cases;
      is-match = { value, ... }: value expr;
      matches = map is-match expressions;
      match-fail = throw "No pattern matched the given expression.";
      match = lib.findFirst (x: x.success) match-fail matches;
    in
      match.value
  ;
in
  {
    inherit match is-function is-string otherwise;
    __functor = self: match;
  }

