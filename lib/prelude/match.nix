{ lib, godel, ... }:
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
        Invalid expresion fund on match statement. All match
        functions must have explicit attributes as parameters.
        To introduce a 'catch-all' function use the
        'match.otherwise' semantic operator followed by the
        'cath-all' function.
      ''
  ;
      
  match = expr: cases:
    let
      expressions = godel.reduce cases;
      is-match = { value, type, ... }:
        let
          try-plain =
            if lib.isFunction value
            then apply-args value expr
            else throw ''
              The "match" statement contains an invalid
              expression. Either use a match operator or
              a function.
            ''
          ;
          try-semantic = value expr;
        in
          if type == types.plain
          then try-plain
          else try-semantic
      ;
      matches = map is-match expressions;
      match-fail = throw "No pattern matched the given expression.";
      match = lib.findFirst (x: x.success) match-fail matches;
    in
      match.value
  ;
in
  {
    inherit match;
  }

