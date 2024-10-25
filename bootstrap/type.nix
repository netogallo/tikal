{ nixpkgs, tikal-meta, ... }: { module-meta, context, test, ... }:
let
  inherit (import ./lib.nix { inherit nixpkgs; }) pretty-print;
  base-type-ctx = { name }: context {
    name = name;
    __functor = _: arg: context (arg // { name = "${name}-instance"; });
    members = {

      instance-context = {
        __description = "The context which surrounds all instances of the type";
        __functor = _: ctx: ctx.focal;
      };
      
      includes = {
        __description = "Check if the given value belongs to this Type";
        __functor = _: ctx: value: ctx.instance-context.surrounds value;
      };

      __functor = {
        __description = "Construct an instance of the type captured by this context.";
        __functor = _: ctx: _: ctx.focal;
      };
    };
  };
  Int = base-type-ctx { name = "Int"; } {

    __functor = _: value:
      if builtins.typeOf value == "int"
      then value
      else if Int.includes value
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

      raw-string = {
        __functor = _: ctx: builtins.toString ctx.focal;
      };

      __functor = {
        __functor = _: ctx: _: op: ctx."${op}";
      };
    };
  };

  Arrow = base-type-ctx { name = "Arrow"; } {

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

  String = base-type-ctx { name = "String"; } {

    __functor = str:
      if builtins.typeOf str == "string"
      then str
      else if String.includes str
      then str.focal
      else throw "Expected a string, got ${pretty-print str}"
    ;

    members = {
    };
  };
  
  make-member = {
    __description = "Convert the spec of a type member into the spec of a context member.";

    __functor = _: spec:
      {
        __functor = _: ctx: spec.type spec ctx;
      }
    ;
  };

  Type = context {
    name = "Type";

    __functor = _: { name, members, ... }@spec: spec;

    members = {

      instance-context = {
        __description = "The context which surrounds all instances of the type";
        __functor = _: ctx:
          let
            spec = ctx.focal;
            members = builtins.mapAttrs (_: v: make-member v) spec.members;
            ctor-attrs = {
              __functor = _: make-member (spec.__functor);
            };
          in
          context (
            {
              name = "${spec.name}-instance";
              inherit members;
            } //
            (if builtins.hasAttr "__functor" spec then ctor-attrs else {})
          )
        ;
      };

      includes = {
        __description = "Check if the given value belongs to this Type";
        __functor = _: ctx: value: ctx.instance-context.surrounds value;
      };

      __functor = {
        __functor = _: ctx: _: ctx.instance-context;
      };
    };
  };

  type = {
    __description = ''
      Define a new type by providing a type spec.
    '';

    __functor = _: Type;

    __tests = {
      "It can create an Int instance" = { _assert }:
        _assert.eq (Int 42).focal 42
      ;
      "It can create an Arrow instance" = { _assert }:
        let
          fn = x: x "+" 42;
          arr = Arrow { from = Int; to = Int; } fn;
        in
          _assert.all [
            (_assert.eq (arr 5).focal 47)
            (_assert.eq (arr (Int 5)).focal 47)
          ]
      ;

      "The Arrow checks the input and return type" = { _assert }:
        let
          fn1 = arr (x: x "+" 5);
          fn2 = arr (x: builtins.toString x.focal);
          arr = Arrow { from = Int; to = Int; };
        in
          _assert.all [
            (_assert.throws (fn1 "wrong").focal)
            (_assert.throws (fn2 3).raw-string)
          ]
        ;

      "The Arrows can be nested" = { _assert }:
        let
          arr = Arrow { from = Int; to = Arrow { from = Int; to = Int; }; };
          fn = arr (x: y: x "+" y);
        in
          _assert.eq (fn 2 3).focal 5
      ;

      "It can define a simple type" = { _assert }:
        let
          Dummy = type {
            name = "Dummy";

            __functor = {
              type = Arrow { from = Int; to = Int; }; #[Int "->" Int];
              __functor = _: i: i "*" 2;
            };

            members = {
            };
          };
          value = Dummy 5;
        in
          _assert.all [
            (_assert.eq value.focal.focal 10)
            (_assert (Dummy.includes value))
          ]
      ;
    };
  };
in
test {
  inherit Int String Arrow type;
}
