{ nixpkgs, tikal-meta }: { module-meta, context, test }:
let
  inherit (import ./lib.nix { inherit nixpkgs; }) pretty-print;
  Int = context {
    name = "Int";

    __functor = _: value:
      if builtins.typeOf value == "int"
      then value
      else if Int.surrounds value
      then value.focal
      else throw "Expected an integer, got ${pretty-print value}"
    ;

    members = {

    };
  };

  Arrow = context {
    name = "Arrow";

    __functor = _: [from to]: { inherit from to; };

    members = {

      from = {
        __functor = _: ctx: ctx.focal.from;
      };

      to = {
        __functor = _: ctx: ctx.focal.to;
      };

      __functor = _: ctx: fn: arg: ctx.to (fn ctx.from arg);
    };
  };

  type = {
    __description = ''
      Define a new type by providing a type spec.
    '';

    make-member = {
      __description = ''
        Convert the spec of a type member into the spec of a context member.
      '';

      __functor = _: spec:
        let
        in
        {
        }
      ;
    };

    __functor = _: spec:
      let
        
      in
      {
        name = spec.name;
      };

    __tests = {

      "It can define a simple type" = { _assert }:
        let
          Dummy = type {
            name = "Dummy";

            __functor = {
              type = Arrow [Int Int]; #[Int "->" Int];
              __functor = _: i: i "*" 2;
            };

            members = {
            };
          };
          value = Dummy 5;
        in
          _assert.eq value.focal 10 
      ;
    };
  };
in
test {
}
