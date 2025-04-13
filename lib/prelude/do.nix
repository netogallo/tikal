{ lib, callPackage, ... }:
let
  parser = callPackage ./do/parser.nix {};
  do-operators = {
    "|>" = {
      precedence = 2;
      operator = "|>";
      fn = f1: f2: arg: f2 (f1 arg);
    };
    "$>" = {
      operator = "$>";
      precedence = 1;
      fn = x: f: f x;
    };
  };
  do-spec = {
    operators = do-operators;
  };
  do = expr: parser.eval (parser.parse do-spec expr);
in
  {
    inherit do;
    demo = {
      "example 1" = rec {
        add = x: y: x + y;
        expression = [ 8 "$>" add 9 "|>" add 5 ];
        result = do expression;
      };
    };
  }
