{ nixpkgs, tikal-meta, prim, callPackage, ... }: { module-meta, context, trivial, test, pretty-print, ... }:
let
  inherit (prim) pretty-print;
  lib = nixpkgs.lib;
  stdenv = nixpkgs.stdenv;
  prim = callPackage ./lib.nix {};

  type-variants = {
    base-type = 0;
    user-type = 1;
    trait = 2;
  };

  InstanceTrait = trait {
    name = "InstanceTrait";
    members = { Self, ... }: {

      __instance-context = {
        __description = ''
          A value containing information about a type instance.
        '';

        type = Any;

        __member = _: {
          Type = Self;
        };
      };
    };
  };

  base-type-ctx = { name }: context {
    name = name;
    __functor = trivial.constructor (arg: context (arg // { name = "${name}-instance"; }));
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


  check-instance-value = {

    __description = ''
    This function applies some strict checks to instance values of user generated
    types. Given that nix is lazy, it is possible that errors in the definition of
    a type do not get caught unitl instance values are used in a particular way.
    This function moves some of this errors to the moment a type instance is created
    by creting a dummy derivation that applies checks during its construction.

    Checks performed:
    - Check that member overriding rules are respected.
    '';

    __functor = _: instance:
      let
        out-str = builtins.toJSON (builtins.mapAttrs (_: builtins.typeOf) instance);
        key = builtins.hashString "sha256" out-str;
        dummy = { ${key} = instance; };
        check-drv = nixpkgs.writeText key out-str;
      in
        dummy."${check-drv.name}"
    ;
  };

  Any = {

    __description = ''
    Used to represent values of any type. This will not wrap the value
    with a context.
    '';

    __functor = _: value: value;
  };

  Int = base-type-ctx { name = "Int"; } {

    __functor = trivial.constructor (
      value:
        if builtins.typeOf value == "int"
        then value
        else if Int.includes value
        then value.focal
        else throw "Expected an integer, got ${pretty-print value}"
      )
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

      to-nix = {
        __member = _: self.focal;
      };

      __functor = {
        __member = _: _: op: self."${op}";
      };
    };
  };

  Arrow = base-type-ctx { name = "Arrow"; } {

    __functor = trivial.constructor ({ From, To }: { inherit From To; });

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

    __functor = _: { constructor, ... }: { Item }:
      let
        item-list = base-type-ctx { name = "List$Item"; } {
          __functor = trivial.constructor(
            items:
              if builtins.typeOf items == "list"
              then map Item items
              else if item-list.includes items
              then item-list.focal
              else throw "Expected a List of Item, got ${pretty-print items}"
          );

          members = { self, ...}: {

            at = {
              __description = "Returns the item at the given index.";
              __member = _: Arrow { From = Int; To = Item; } (i: lib.elemAt self.focal i.focal); 
            };

            "!!" = {
              __member = _: self.at;
            };

            foldl = {
              __description = "Reduce the list from left to right.";
              __member = _: { State }: fn: state:
                let
                  fn' = Arrow { From = State; To = Arrow { From = Item; To = State;}; } fn;
                in
                  builtins.foldl' fn' state self.focal
              ;
            };

            __functor = {
              __member = _: _: prop: self.${prop};
            };
          };
        };
      in
        constructor item-list
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

    __functor = _: spec: ctx:
      let
        type =
          if builtins.hasAttr "type" spec
          then spec.type
          else throw "Member function definitions must have a 'type' attribute."
        ;
      in
      type spec.__member ctx
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
        override-trait = { current-member, new-member, ... }:
          if new-member.is-abstract
          then current-member
          else throw "The member ${name} name cannot be overriden."
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

  get-ctor-spec =
    prim.getAttrDeepPoly {
      strict = true;
      validate = { result, ... }: builtins.typeOf result == "lambda"; 
      error = { obj, ... }: ''
      The spec:

      ${pretty-print obj}

      does not have a 'new' property. Type definitions must have a 'new'
      property. This property must be a lambda that takes as argument
      the constructor context and produces a constructor spec.
      '';
    } "new"
  ;

  Type = context {
    name = "Type";

    __functor = trivial.constructor ({ name, members, ... }@spec: spec);

    members = { self, ...}: {

      instance-context = {
        __description = "The context which surrounds all instances of the type";
        __member = _:
          let
            spec = self.focal;
            members = ctx: builtins.mapAttrs make-type-member (spec.members ctx);
            ctor-spec = get-ctor-spec spec {}; 
            ctor-attrs = {
              __functor = trivial.constructor (make-ctor ctor-spec);
            };
          in
          context {
            name = "${spec.name}-instance";
            inherit members;
            __functor = trivial.constructor (make-ctor ctor-spec);
          }
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
            lib.foldl' acc value ([InstanceTrait] ++ self.implied-contexts)
        ;
      };

      includes = {
        __description = "Check if the given value belongs to this Type";
        __member = _: value: self.instance-context.surrounds value;
      };

      __functor = {
        __member = _: _: value:
          let
            spec = self.focal;
          in
          if self.instance-context.surrounds value
          then value
          else
            check-instance-value (self.extend-with-implied (self.instance-context value))
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
        is-abstract = !(builtins.hasAttr "__member" spec);
        __member =
          if is-abstract
          then _: throw "The trait member '${name}' is abstract and has not been overriden."
          else spec.__member
        ;
        __override = _: "The member '${name}' is a trait member and cannot be overriden.";
        trait-spec = spec // { inherit __member __override; };
      in
        (make-any-member name trait-spec) // { inherit is-abstract; }
    ;
  };

  Trait = context {
    name = "Trait";

    __functor = trivial.constructor({ name, members, ... }@spec: spec);

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

  kind = {
    any = 0;
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

            new = { ... }: {
              type = Arrow { From = Int; To = Int; }; #[Int "->" Int];
              __member = i: i "*" 2;
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

            new = { ... }: {
              type = Arrow { From = Int; To = Int; };
              __member = i: i;
            };

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
          _assert.eq ((value.replicate 3) "!!" 1).to-nix expected.to-nix
      ;

      "Types have an instance context" = { _assert, ... }:
        let
          Test = type {
            name = "instance";
            new = { ... }: { type = Arrow { From = Int; To = Int; }; __member = i: i; };
            members = { ... }: {};
          };
          test = Test 1;
        in
          _assert (test.__instance-context.Type.includes test)
      ;

      "Traits cannot override concrete members" = { _assert, ... }:
        let
          Dodgey = type {
            name = "Dodgey";

            new = { ... }: { type = Arrow { From = Int; To = Int; }; __member = i: i; };

            members = { self, ... }: {

              __instance-context = {
                type = Any;

                __member = _: "";
              };
            };
          };
        in
          _assert.throws (Dodgey 5)
      ;

      "Types can be extended with traits" = { _assert, ... }:
        let
          Dummy = type {
            name = "Dummy";

            new = { ... }: {
              type = Arrow { From = Int; To = Int; };
              __member = i: i;
            };

            members = { self, ... }: {

              concat = {
                type = Arrow { From = Dummy; To = Dummy; };
                __member = _: other: self.focal "+" other.focal;
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
                __member = _: items: items.foldl { State = Self; } (s: i: s.concat i) self;
              };
            };
          };

          value = Dummy 5;
        in
          _assert.eq 20 (value.concat-many [ 1 2 3 4 5 ]).focal.focal
      ;

      "It can define generic types" = { _assert, ... }:
        let
          Cell = type {
            name = "Cell";
            type-args = { Item = kind.any; };

            new = { Item, ...}: {
              type = Arrow { From = Item; To = Item; };
              __member = _: value: value;
            };

            members = { self, Item, ... }: {

              get = {
                type = Item;
                __member = _: self.focal;
              };

              set = {
                type = Arrow { From = Item; To = Cell { inherit Item; }; };
                __member = _: value: Cell { inherit Item; } value;
              };
            };
          };
          iCell = Cell { Item = Int; } 42;
        in
          _assert.all [
            (_assert.eq iCell.get 42)
          ]
      ;
    };
  };
in
test {
  inherit List Int String Arrow type;
}
