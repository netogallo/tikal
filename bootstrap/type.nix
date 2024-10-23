{ nixpkgs, tikal-meta, ... }: { module-meta, context, test, ... }:
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

      "*" = {
        __functor = _: ctx: arg-any: Int(ctx.focal * (Int arg-any).focal); 
      };
      
      "+" = {
        __functor = _: ctx: arg-any: Int(ctx.focal + (Int arg-any).focal);
      };

      __functor = {
        __functor = _: ctx: _: op: ctx."${op}";
      };
    };
  };

  Arrow = context {
    name = "Arrow";

    __functor = _: { from, to }: { inherit from to; };

    members = {

      from = {
        __functor = _: ctx: ctx.focal.from;
      };

      to = {
        __functor = _: ctx: ctx.focal.to;
      };

      __functor = {
        __functor = _: ctx: _: fn: arg: ctx.to (fn (ctx.from arg));
      };
    };
  };

  type = rec {
    __description = ''
      Define a new type by providing a type spec.
    '';

    make-member = {
      __description = ''
        Convert the spec of a type member into the spec of a context member.
      '';

      __functor = _: spec:
        {
          __functor = _: ctx: spec.type spec ctx;
        }
      ;
    };

    __functor = _: spec:
      let
        ctor-attrs = {
          __functor = _: make-member (spec.__functor);
        };
        members = builtins.mapAttrs (_: v: make-member v) spec.members;
      in
      {
        inherit members;
        name = spec.name;
      }
      // (if builtins.hasAttr "__functor" spec then ctor-attrs else {});

    __tests = {
      "It can create an Int instance" = { _assert }:
        _assert.eq (Int 42).focal 42
      ;
      "It can create an Arrow instance" = { _assert }:
        let
          fn = x: x "+" 42;
          arr = Arrow { from = Int; to = Int; } fn;
        in
          _assert.eq (arr 5).focal 47
        ;

#      "It can define a simple type" = { _assert }:
#        let
#          Dummy = type {
#            name = "Dummy";
#
#            __functor = {
#              type = Arrow { from = Int; to = Int; }; #[Int "->" Int];
#              __functor = _: i: i "*" 2;
#            };
#
#            members = {
#            };
#          };
#          value = Dummy 5;
#        in
#          _assert.eq value.focal 10 
#      ;
    };
  };
in
test {
  inherit type;
}
