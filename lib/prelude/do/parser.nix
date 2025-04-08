{ lib, ... }:
let
  render-error = { expression, ... }@state: message:
    ''Could not parse the expression, the error is: ${message}''
  ;

  node = op: vals:
    if lib.length vals != 2
    then throw "Error in the code, node called with unexpected number of args"
    else
      {
        operator = op;
        left = lib.elemAt vals 1;
        right = lib.elemAt vals 0;
      }
  ;

  reduce-values = state: op-stack: val-stack:
    let
      acc = values: op:
        if lib.length values < 2
        then
          throw (render-error state "Wrong number of arguments to operator ${op.operator}.")
        else
          [(node op (lib.take 2 values))] ++ lib.drop 2 values
      ;
    in
      lib.foldl acc val-stack op-stack
  ;

  handle-operator = { val-stack, op-stack, ... }@state: operator:
    let
      by-precedence = lib.partition (o: o.precedence >= operator.precedence) op-stack;
    in
      state //
      {
        val-stack = reduce-values state by-precedence.right val-stack;
        op-stack = [ operator ] ++ by-precedence.wrong;
      }
  ;

  handle-value = { val-stack, ... }@state: value:
    state // { val-stack = [value] ++ val-stack; };

  parse-step = args: value:
    if is-operator value
    then handle-operator args value
    else handle-value args value
  ;

  mk-value = spec: value: { inherit value; };
  mk-operator = { operators, ... }: op-token: operators.${op-token};
  is-value = lib.hasAttr "value";
  is-operator = lib.hasAttr "operator";
  is-operator-token = spec: token:
    lib.isString token && lib.hasAttr token spec.operators
  ;
  app-operator = {
    operator = null;
    precedence = 9;
    fn = f: x: f x;
  };

  prepare = spec: expression:
    let
      acc-value = state: next:
        # check if we need to add an implied application
        # this happens if two values appear in succession
        # w/o any operator between them.
        if lib.length state > 0 && is-value (lib.last state)
        then state ++ [app-operator (mk-value spec next)]
        else state ++ [(mk-value spec next)]
      ;
        
      acc = state: next:
        if is-operator-token spec next
        then state ++ [(mk-operator spec next)]
        else acc-value state next
      ;
    in
      lib.foldl acc [] expression
  ;

  parse = spec: expression:
    let
      initial = {
        val-stack = [];
        op-stack = [];
        inherit expression;
      };
      prepared-expression = prepare spec expression;
      intermediate = lib.foldl parse-step initial prepared-expression;
    in
      lib.head (reduce-values intermediate intermediate.op-stack intermediate.val-stack)
  ;
  fold-ast = on-node: on-value: ast:
    let
      continue = fold-ast on-node on-value;
    in
      if is-value ast
      then on-value ast
      else
        on-node ast (continue ast.left) (continue ast.right)
  ;
  eval =
    let
      on-value = v: v.value;
      on-node = node: v1: v2: node.operator.fn v1 v2;
    in
      fold-ast on-node on-value
  ;
in
  {
    inherit parse eval;
  }
