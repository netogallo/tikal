{ nixpkgs, tikal-meta, prim, callPackage, ... }: { module-meta, context, trivial, test, pretty-print, is-tikal-value, ... }:
let
  inherit (prim) pretty-print;
  lib = nixpkgs.lib;
  stdenv = nixpkgs.stdenv;
  prim = callPackage ./lib.nix {};
  inherit (builtins) typeOf;

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

      type-fullname = {
        __description = "The full qualified name of the type.";
        __member = _: name;
      };

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

      generic-type = {
        __description = "This should not be used for generic types";
        __member = _: null;
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

    generic-type = null;
  };

  Bool = base-type-ctx { name = "Bool"; } {
    
    __functor = trivial.constructor (
      value:
        if builtins.typeOf value == "bool"
        then value
        else if Bool.includes value
        then value.focal
        else throw "Expected a boolean, got ${pretty-print value}"
    );

    members = { self, ... }: {

      _to-nix = {
        __member = _: self.focal;
      };

      match = {
        __member = _: pattern:
          if self.focal
          then pattern.True
          else pattern.False
        ;
      };

      "&&" = {
        __member = _: other:
          Bool (self.focal && (Bool other).focal)
        ;
      };

      __functor = {
        __member = _: _: name: self.${name};
      };
    };
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

      match = {
        __member = _: { Result }: pattern:
          let
            key = builtins.toString self.focal;
          in
            if builtins.hasAttr "${key}" pattern
            then Result (pattern.${key})
            else if builtins.hasAttr "_" pattern
            then Result pattern._
            else throw "Pattern match failed! The pattern '${pretty-print pattern}' did not match ${self.focal}."
        ;
      };

      raw-string = {
        __member = _: builtins.toString self.focal;
      };

      _to-nix = {
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

    __functor = trivial.constructor (
      str:
        if builtins.typeOf str == "string"
        then str
        else if String.includes str
        then str.focal
        else throw "Expected a string, got ${pretty-print str}"
    );

    members = { self, ... }: {

      _to-nix = {
        __member = _: self.focal;
      };

      "==" = {
        __member = _: other:
          Bool (self.focal == (String other).focal)
        ;
      };

      __functor = {
        __member = _: _: prop: self.${prop};
      };
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

            any = {
              __member = _: fn:
                let
                  fn' = Arrow { From = Item; To = Bool; } fn;
                in
                  Bool (builtins.any (v: (fn' v)._to-nix) self.focal)
              ;
            };

            filter = {
              __member = _: fn:
                let
                  fn' = v: (Arrow { From = Item; To = Bool; } fn v)._to-nix;
                in
                  List { inherit Item; } (builtins.filter fn' self.focal)
              ;
            };

            length = {
              __member = _: Int (builtins.length self.focal);
            };

            map = {
              __member = _: fn: List { inherit Item; } (builtins.map fn self.focal);
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
        type-args = prim.getAttrDeep "type-args" spec;
        is-generic = type-args != null;
        member = {
          __type = type;
          __member = ctx: type (spec.__member ctx);
        };
        generic-member = {
          __type = type;
          __member = ctx: targs: type targs (spec.__member (ctx // targs));
        };
      in
        if is-generic
        then generic-member
        else member
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

  spec-defaults = {
    generic-type = null;
  };

  Type = context {
    name = "Type";

    __functor = trivial.constructor ({ name, members, ... }@spec: spec-defaults // spec);

    members = { self, ...}: {

      type-fullname = {
        __description = "The full name of the type";
        __member = _: self.focal.name;
      };

      generic-type = {
        __description = "The generic type (if any) from which this type is derived";
        __member = _: self.focal.generic-type;
      };

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

      __tests = {
        __description = "The tests for this type that are defined in the spec";
        __member = _:
          if builtins.hasAttr "__tests" self.focal
          then self.focal.__tests
          else {}
        ;
      };

      __functor = {
        __member = _: _: value:
          let
            spec = self.focal;
            type-args = prim.getAttrDeepPoly { default = {}; } "type-args" spec;
            is-generic = type-args != {};
            Self = Type spec-instance;
            targs-ctx = value // { inherit Self; type-args = value; };
            spec-instance =
              spec
              // {
                generic-type = self;
                type-args = {};
                new = args: spec.new (args // targs-ctx);
                members = args: spec.members (args // targs-ctx);
              }
            ;
          in
          if is-generic
          then Self
          else if self.instance-context.surrounds value
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

  TypeClass = Any;

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

  Set = type {

    name = "Set";

    type-args = { "*" = kind.any; };

    new = { type-args, ... }: {
      type = Arrow { From = Any; To = Any; };
      __member = arg:
        let
          field-mapper = key: t:
            let
              allow-empty =
                t.generic-type != null
                && t.generic-type.type-fullname == Maybe.type-fullname
              ;
            in {
              value = 
                if builtins.hasAttr key arg
                then t arg."${key}"
                else t null
              ;
              valid =
                if builtins.hasAttr key arg || allow-empty
                then true
                else throw ''The set "${pretty-print arg}" is missing the key "${key}"''
              ;
            }
          ;
          value-with-validation = builtins.mapAttrs field-mapper type-args;
          validate = lib.all (x: x) (lib.mapAttrsFlatten (_: v: v.valid) value-with-validation);
        in
          if validate
          then builtins.mapAttrs (_: v: v.value) value-with-validation
          else throw ''The value "${pretty-print arg}" does not match the Set type.''
      ;
    };

    members = { self, type-args, ... }:
      let
        create-member-fields = name:
          let
            field-type = type-args."${name}";
            field-members = {
              ${name} = {
                type = field-type;
                __member = _: self.focal."${name}";
              };
            };
            field-members-names = builtins.attrNames field-members;
            valid = builtins.all field-is-allowed field-members-names;
          in
            if valid
            then field-members
            else throw "Set cannot use a reserved field"
        ;
        member-fields-acc = s: name: s // create-member-fields name;
        member-fields =
          lib.foldl
          member-fields-acc
          {}
          (builtins.attrNames type-args)
        ; 
        set-members = {
          _lookup-any = {
            type = Arrow { From = String; To = Any; };
            __member = _: path: prim.getAttrDeepPoly { strict = false; default = Nothing { Value = Any; }; } path self;  
          };
        };
        set-reserved-members = builtins.attrNames set-members;
        field-is-allowed = field:
          if builtins.all (f: f != field) set-reserved-members
          then true
          else throw "The field name '${field}' is reserved and cannot be used as a 'Set' field."
        ;
      in
        member-fields
        // set-members
    ;

    __tests = {
      "A typed set can be defined and used." = { _assert, ... }:
        let
          MySet = Set { Test = Int; Other = String; };
          test = MySet { Test = 5; Other = "5"; };
        in
          _assert.all [
            (_assert.eq test.Test._to-nix 5)
            (_assert.eq test.Other._to-nix "5")
          ]
      ;

      "A typed set checks that all attributes are present" = { _assert, ... }:
        let
          MySet = Set { Test = Int; Other = String; };
        in
          _assert.throws (MySet { Test = 5; })
      ;

      "A typed set allows optional attributes" = { _assert, ... }:
        let
          MySet = Set { Test = Maybe { Value = Int; }; };
        in
          _assert.all [
            (_assert (MySet {}).Test.is-nothing._to-nix)
            (_assert (!(MySet { Test = 5; }).Test.is-nothing._to-nix))
          ]
      ;
    };
  };

  Maybe = type {
    name = "Maybe";

    __description = ''
    Represents an optional value. It provides safe methods to access the optional
    value in a consice way.
    '';

    type-args = { Value = kind.any; };

    new = { Value, ... }: {
      type = Arrow { From = Any; To = Any; };
      __member = arg:
        if arg == null
        then null
        else Value arg
      ;
    };

    members = { self, Value, ... }: {

      match-any = {

        __description = ''
        Method for pattern matching this option type. It offers a syntacs like:

        <code>
          maybe-value.match-any {
            Just = value: fn value;
            Nothing = default-value;
          }
        </code>

        This is the non-generic version of the 'match' method which doesn't require
        a typecheck on the result.
        '';

        type = Arrow { From = Set { Just = Arrow { From = Value; To = Any; }; Nothing = Any; }; To = Any; };
        __member = _: pattern:
          if self.focal == null
          then pattern.Nothing
          else pattern.Just self.focal
        ;
      };

      is-nothing = {
        type = Bool;
        __member = _: self.focal == null;
      };

      is-just = {
        type = Bool;
        __member = _: self.focal != null;
      };

      match = {
        type-args = { Result = kind.any; };
        type = { Result, ... }: Arrow {
          From = Set { Just = Arrow { From = Value; To = Result; }; Nothing = Result; };
          To = Result;
        };
        __member = { Result, ... }: self.match-any;
      };

      to-value = {
        type = Value;
        __member = _:
          self.is-just.match {
            True = self.focal;
            False = throw "'to-value' called on an empty option.";
          };
      };
    };
  };

  Nothing = targs: Maybe targs null;

  Tuple2 = type {
    name = "Tuple2";
    type-args = { "1" = kind.any; "2" = kind.any; };

    new = { type-args, ... }: {
      type = Arrow { From = Any; To = Any; };
      __member = arg:
        let
          not-list-error = "The value '${pretty-print arg}' must be a List of length 2.";
          value1 = type-args."1" (builtins.elemAt arg 0);
          value2 = type-args."2" (builtins.elemAt arg 1);
        in
          if typeOf arg != "list" || builtins.length arg != 2
          then throw not-list-error
          else { "1" = value1; "2" = value2; }
      ;
    };

    members = { self, type-args, ... }: {
      
      _1 = {
        type = type-args."1";
        __member = _: self.focal."1";
      };

      _2 = {
        type = type-args."2";
        __member = _: self.focal."2";
      };
    };
  };

  match-union-type = { type, value }:
    let
      m-type = Maybe { Value = type; };
      match-tikal =
        if type.includes value
        then m-type value
        else m-type null
      ;
      prim-props = List { Item = Tuple2 { "1" = String; "2" = Any; }; } [
        [ "int" Int ]
        [ "string" String ]
        [ "bool" Bool ]
      ];
      is-prim =
        prim-props.any (
          props:
            props._1 "==" (typeOf value) "&&"
            (props._2.type-fullname == type.type-fullname)
        )
      ;
    in
      if is-tikal-value value
      then match-tikal
      else if is-prim._to-nix
      then m-type value
      else m-type null
  ;

  print-type = t: t.type-fullname;

  trace-value = m: v: builtins.trace "{ message = ${m}; type = ${builtins.typeOf v}; }" (builtins.trace v v);

  Union = type {

    name = "Union";
  
    __description = ''
      Type that represents an Union of types. For specific values, it will be able
      to directly convert the value into the right value within the union. For other
      values, it will use regular typechecking to match the value into the respective
      item in the union. The type argument attributes can have any names. Instance
      values of a union will offer members named after the type attributes which produce
      a "Maybe" value indicating wether that value matched the union or not.

      Note that if a primitive attribute set is provided, the Union's constructor
      *will* have to evaluate the attribute set in order to establish wether the
      set matches any of the types in the Union.
    '';

    new = { Self, type-args, ... }: {
      type = Arrow { From = Any; To = Any; };
      __member = value:
        let
          match-type = _: ty: match-union-type { type = ty; inherit value; };
          union = builtins.mapAttrs match-type type-args;
          attr-values = List { Item = Any; } (builtins.attrValues union);
          union-values = (attr-values.filter (m: m.is-just)).map (m: m.to-value);
          validate-union =
            union-values.length.match { Result = Any; } {
              "0" = throw "The value ${pretty-print value} does not match the type ${print-type Self}";
              "1" = union;
              _ = throw "The union type ${print-type Self} is ambigous. Multiple matches for ${pretty-print value}";
            };
        in
          validate-union
      ;
    };

    members = { ... }: {};
    
    type-args = { "*" = kind.any; };

    __tests = {
      "Union works on built in types" = { _assert, ... }:
        let
          MyUnion = Union { Num = Int; Str = String; Bo = Bool; };
          bUnion = MyUnion true;
        in
          _assert bUnion.focal.Bo.is-just._to-nix
      ;
    };
  };

  type = Type;

  type-export = {
    __description = ''
      Define a new type by providing a type spec.
    '';

    __functor = _: spec:
      let
        module-spec-overrides = {
          name = "${module-meta.name}.${spec.name}"; 
        };
      in
        Type (spec // module-spec-overrides)
    ;

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
          _assert.eq ((value.replicate 3) "!!" 1)._to-nix expected._to-nix
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
              __member = value: value;
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
          ICell = Cell { Item = Int; };
          iCell = ICell 42;
          iCell2 = iCell.set 43;
        in
          _assert.all [
            (_assert.eq iCell.get._to-nix 42)
            (_assert.eq iCell2.get._to-nix 43)
            (_assert.throws ((iCell.set "hello").get.focal))
          ]
      ;
    };
  };

  maybe = {

    __description = "";

    __functor = _: Maybe;

    __tests = {

      "match-any applies function when it contains a value." = { _assert, ... }:
        let
          m-value = Maybe { Value = Int; } 41;
          actual = m-value.match-any {
            Just = n: n "+" 1;
            Nothing = 666;
          };
          expected = Int 42;
        in
          _assert.eq actual._to-nix expected._to-nix
      ;

      "match applies a function when it contains a value." = { _assert, ... }:
        let
          m-value = Maybe { Value = Int; } 41;
          actual = m-value.match { Result = Int; } {
            Just = n: n "+" 1;
            Nothing = 666;
          };
          expected = Int 42;
        in
          _assert.eq actual._to-nix expected._to-nix
      ;

      "match checks that the return value has the correct type." = { _assert, ... }:
        let
          m-value = Maybe { Value = Int; } 41;
          actual = m-value.match { Result = Int; } {
            Just = x: x.raw-string;
            Nothing = "No";
          };
        in
          _assert.throws actual.focal
      ;
    };
  };
in
test {
  inherit List Int String Any Arrow Maybe maybe Set Union;
  type = type-export;
  Type = TypeClass;
}
