{ nixpkgs, tikal-meta, prim, ... }: { module-meta, context, test, pretty-print, ... }:
let
  inherit (prim) pretty-print;
  lib = nixpkgs.lib;

  type-variants = {
    base-type = 0;
    user-type = 1;
    trait = 2;
  };

  base-type-ctx = { name }: context {
    name = name;
    __functor = _: arg: context (arg // { name = "${name}-instance"; });
    members = { self, ...}: {

      type-variant = {
        __description = "Indicate that these are base (builtin) types";
        __member = _: _: type-variants.base-type;
      };

      instance-context = {
        __description = "The context which surrounds all instances of the type";
        __member = _: self.focal;
      };
      
      includes = {
        __description = "Check if the given value belongs to this Type";
        __member = _: value: self.instance-context.surrounds value;
      };

      __functor = {
        __description = "Construct an instance of the type captured by this context.";
        __member = _: _: self.focal;
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

    members = { self, ...}: {

      "*" = {
        __member = _: arg-any: Int(self.focal * (Int arg-any).focal); 
      };
      
      "+" = {
        __member = _: arg-any: Int(self.focal + (Int arg-any).focal);
      };

      raw-string = {
        __member = _: builtins.toString self.focal;
      };

      __functor = {
        __member = _: _: op: self."${op}";
      };
    };
  };

  Arrow = base-type-ctx { name = "Arrow"; } {

    __functor = _: { From, To }: { inherit From To; };

    members = { self, ... }: {

      from = {
        __member = _: self.focal.From;
      };

      to = {
        __member = _: self.focal.To;
      };

      __functor = {
        __member = _: _: fn: arg: self.to (fn (self.from arg));
      };
    };
  };

  String = base-type-ctx { name = "String"; } {

    __functor = _: str:
      if builtins.typeOf str == "string"
      then str
      else if String.includes str
      then str.focal
      else throw "Expected a string, got ${pretty-print str}"
    ;

    members = {
    };
  };

  List = base-type-ctx { name = "List$1"; } {

    __functor = _: { Item }:
      let
        item-list = base-type-ctx { name = "List$Item"; } {
          __functor = _: items:
            if builtins.typeOf items == "list"
            then map Item items
            else if item-list.includes items
            then item-list.focal
            else throw "Expected a List of Item, got ${pretty-print items}"
          ;

          members = { self, ...}: {

            at = {
              __description = "Returns the item at the given index.";
              __member = _: Arrow { From = Int; To = Item; } (i: lib.elemAt self.focal i.focal); 
            };

            "!!" = {
              __member = _: self.at;
            };

            __functor = {
              __member = _: _: prop: self.${prop};
            };
          };
        };
      in
        item-list
    ;

    members = { self, ...}: {

      __functor = {
        __description = "Constructs a list of the specified 'Item' type.";
        __member = _: _: self.focal;
      };
    };
  };
  
  make-ctor = {
    __description = "Convert the spec of a type constructor into the spec of a context constructor.";

    __functor = _: spec:
      let
        type =
          if builtins.hasAttr "type" spec
          then spec.type
          else throw "Member function definitions must have a 'type' attribute."
        ;
      in
      {
        __functor = _: ctx: type spec ctx;
      }
    ;
  };

  make-any-member = {
    __description = "Basic conversion of a typed member into a context member.";

    __functor = _: name: spec:
      let 
        type =
          if builtins.hasAttr "type" spec
          then spec.type
          else throw "Member function definitions must have a 'type' attribute."
        ;
      in
      {
        __type = type;
        __member = ctx: type (spec .__member ctx);
      }
    ;
  };

  make-type-member = {
    __description = ''
      Convert the spec of a user type member into a context member. Below are details
      of all the considerations that are used for this step.

      # Overriding

      These are the rules that govern how members of a type can be overriden.

      ## Traits
      When a type instance is extended with a trait, the abstract members of the
      trait will be masked with the implementation of existing members of the
      instance. If the type of the trait member doesn't match the type of the
      instance member, overriding will fail.
    '';

    __functor = _: name: spec:
      let
        base-member = make-any-member name spec;
        override-trait = { current-member, ... }:
          # Todo: check the type
          current-member
        ;
        __override = { extension, ...}@args:
          if extension.focal.type-variant == type-variants.trait
          then override-trait args
          else throw "The member ${name} cannot be overriden"
        ; 
      in
        base-member
        // {
          inherit __override;
        }
    ;
  };

  Type = context {
    name = "Type";

    __functor = _: { name, members, ... }@spec: spec;

    members = { self, ...}: {

      instance-context = {
        __description = "The context which surrounds all instances of the type";
        __member = _:
          let
            spec = self.focal;
            members = ctx: builtins.mapAttrs make-type-member (spec.members ctx);
            ctor-attrs = {
              __functor = _: make-ctor (spec.__functor);
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

      implied-contexts = {
        __description = ''
        Contains the list of contexts that are implied by this context. These
        contexts will be used to extend the instances of this type.
        '';

        __member = _:
          if builtins.hasAttr "implies" self.focal
          then self.focal.implies
          else []
        ;
      };

      extend-with-implied = {
        __description = ''
        Extend a context with all the implied contexts asociated with this
        type.
        '';

        __member = _: value:
          let
            extend-context = { Self = self; };
            acc = state: ctx: state.extend-with-context extend-context ctx.instance-context;
          in
            builtins.foldl' acc value self.implied-contexts
        ;
      };

      includes = {
        __description = "Check if the given value belongs to this Type";
        __member = _: value: self.instance-context.surrounds value;
      };

      __functor = {
        __member = _: _: value:
          if self.instance-context.surrounds value
          then value
          else
            self.extend-with-implied (self.instance-context value)
        ;
      };
    };
  };

  make-trait-member = {
    __description = ''
      Convert a trait member spec into the member that will be used by the resulting
      context. This includes:
       - adding the appropiate overriding semantics
       - raising errors if an abstract member is called
       - prevent further overriding
    '';

    __functor = _: name: spec:
      let
        __member =
          if builtins.hasAttr "__member" spec
          then spec.__member
          else _: throw "The trait member '${name}' is abstract and has not been overriden."
        ;
        __override = _: "The member '${name}' is a trait member and cannot be overriden.";
        trait-spec = spec // { inherit __member __override; };
      in
        make-any-member name trait-spec
    ;
  };

  Trait = context {
    name = "Trait";

    __functor = _: { name, members, ... }@spec: spec;

    members = { self, ...}: {
      
      type-variant = {
        __description = "Indicate that this type is a trait.";
        __member = _: type-variants.trait;
      };

      instance-context = {
        __description = "The context used to extend values with this trait";
        __member = _:
          let
            spec = self.focal;
            members = ctx: builtins.mapAttrs make-trait-member (spec.members ctx);
          in
            context {
              name = "${spec.name}-trait-instance";
              type-variant = type-variants.trait;
              inherit members;
              __functor = _: _: "The trait instance context '${spec.name}' can only be used to extend contexts.";
            }
        ;
      };

      __functor = {
        __member = _: _: instance: throw "Error";
      };
    };
  };

  trait = {
    __description = ''
      Function that allows defining traits.

      Traits specify an interface that must be supported by a type and provide
      additional member functions that wrap around said interface.
    '';

    __functor = _: Trait;
  };

  type = {
    __description = ''
      Define a new type by providing a type spec.
    '';

    __functor = _: Type;

    __tests = {
      "It can create an Int instance" = { _assert, ... }:
        _assert.eq (Int 42).focal 42
      ;
      "It can create an Arrow instance" = { _assert, ... }:
        let
          fn = x: x "+" 42;
          arr = Arrow { From = Int; To = Int; } fn;
        in
          _assert.all [
            (_assert.eq (arr 5).focal 47)
            (_assert.eq (arr (Int 5)).focal 47)
          ]
      ;

      "The Arrow checks the input and return type" = { _assert, ... }:
        let
          fn1 = arr (x: x "+" 5);
          fn2 = arr (x: builtins.toString x.focal);
          arr = Arrow { From = Int; To = Int; };
        in
          _assert.all [
            (_assert.throws (fn1 "wrong").focal)
            (_assert.throws (fn2 3).raw-string)
          ]
        ;

      "The Arrows can be nested" = { _assert, ... }:
        let
          arr = Arrow { From = Int; To = Arrow { From = Int; To = Int; }; };
          fn = arr (x: y: x "+" y);
        in
          _assert.eq (fn 2 3).focal 5
      ;

      "It can define a simple type" = { _assert, ... }:
        let
          Dummy = type {
            name = "Dummy";

            __functor = {
              type = Arrow { From = Int; To = Int; }; #[Int "->" Int];
              __functor = _: i: i "*" 2;
            };

            members = { ... }: {
            };
          };
          value = Dummy 5;
        in
          _assert.all [
            (_assert.eq value.focal.focal 10)
            (_assert (Dummy.includes value))
          ]
      ;

      "Types can define member functions" = { _assert, ... }:
        let
          Member = type {
            name = "Member";

            members = { self, ... }: {

              replicate = {
                type = Arrow { From = Int; To = List { Item = Int; }; };
                __member = _: times: map (_: self.focal) (lib.range 1 times.focal);
              };
            };
          };
          value = Member 5;
          input = Int 5;
          expected = input;
        in
          _assert.eq ((value.replicate 3) "!!" 1).focal expected.focal
      ;

      "Types can be extended with traits" = { _assert, ... }:
        let
          Dummy = type {
            name = "Dummy";

            members = { self, ... }: {

              concat = {
                type = Arrow { From = Dummy; To = Dummy; };
                __member = _: other: self.focal + other.focal;
              };
            };

            implies = [
              DummyTrait
            ];
          };

          DummyTrait = trait {
            name = "DummyTrait";

            members = { self, Self, ... }: {
              concat = {
                type = Arrow { From = Self; To = Self; };
              };

              concat-many = {
                type = Arrow { From = List { Item = Self; }; To = Self; };
                __member = _: items: builtins.foldl' (s: i: s.concat i) self items.focal;
              };
            };
          };

          value = Dummy 5;
        in
          _assert.eq 20 (value.concat-many [ 1 2 3 4 5 ]).focal
      ;
    };
  };
in
test {
  inherit List Int String Arrow type;
}
