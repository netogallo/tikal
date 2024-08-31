{
  tikal ? import ../default.nix {}
}:
let
  inherit (tikal.lib.types) core;
in
rec {

  Int = core.new-type "Int" {
    module = "Tikal.Nix.Types";

    __prim = ''
      { lib, result, .. }: {
        new = prim:
          if lib.isType "int" prim
          then result { value = prim; }
          else result { error = "Expecting an integer"; }
        ; 
      }
    '';

    members = { self-type }: {
      # begin methods

      _o = core.member {
        # begin _o

        __description = "Add two integers";

        type = Function [Int] Int;

        __functor = _: { self, ... }: other: self + other;
    };
  };

  FunctionMono = core.new-type "FunctionMono" {
    # begin FunctionMono

    __description = "Function type with unknown argument types";

    __prim = ''
      { lib, result, .. }: {
        new = prim:
          if lib.isType "lambda" prim
          then result { value = prim; }
          else result { error = "Expected a lambda"; }
        ;
      }
    '';

    members = { self-type }: {
      # begin methods

      _o = {
        # begin _o

        __description = "Compose two functions";

        type = [[Function] Function];

        __functor = _: { self, ... }: other: x: self (other x);

        # end _o
      };
    };

    # end FunctionMono
  };

  Function = core.newType "Function" {
    # begin Function

    type-vars = {
      input = core.Type;
      output = core.Type;
    };

    inherits = {
      function-mono = FunctionMono
    };

    members = { self-type, input, output }: {

    };

    # end Function
  };

  String = core.newType "String" {
    module = "Tikal.Nix.Types";
    haskell = '''';

    members = { self-type }: {
      length = {
        # begin length
        __description = "Returns the length of the string";

        type = Int;

        __functor = _: { self, ... }: builtins.length self;

        # end length
      };

      _o = {
        # begin _o
        __description = "Concatenates two strings";

        type = Function [String] String;

        __functor = _: self: other: self + other;

        # end _o
      };
    };
  };
}
