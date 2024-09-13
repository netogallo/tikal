{
  __description = ''
    This module contains the core types that are used throughout Tikal to describe
    system configurations.
  '';

  __functor = self: { Set, Type, ... }: rec {

    Assert = Type {
      name = "Assert";

      __description = ''
        Helper class that can be used to write unit tests.
      '';

      __functor = self: { Result, ... }: Result.result;

      members = { self-type, ... }: {

        is-true = {

          type = Bool.to self-type;

          __functor = _: { self, ...}: value:
            value.match {
              true = _: self;
              false = _: throw "Assert error. Expected true, got false";
            }
          ;
        };
      };
    };

    Bool = Type {
      name = "Bool";

      __description = ''
        This type represents the Nix 'bool' type
      '';
      
      __functor = self: { Result, ... }: prim:
        if builtins.typeOf prim == "bool"
        then Result.result prim
        else Result.error "A nix bool is needed to construct the Bool type"
      ;

      members = { self-type, ...}: {

        match = {
          __description = ''
            Pattern match between the true/false value of Bool.
          '';

          type =
            {
              type-args = { a = Type; };
              __functor = _: { a }:
                (Set { true = a; false = a; }).to a
              ;
            };

          __functor = _: { self, ... }: { true, false }: { a }: 
            if self.prim self-type
            then true
            else false
          ;
        };
      };
    };

    Int = Type {

      name = "Int";

      __description = ''
        This type represents the Nix 'int' type.
      '';

      __functor = self: { Result, ... }: prim:
        if builtins.typeOf prim == "int"
        then Result.result prim
        else Result.error "A nix int is needed to construct the Int type"
      ;
    };

    String = Type {

      name = "String";

      __description = ''
        This type represents the Nix 'string' type.
      '';

      __functor = self: { Result, ... }: prim:
        if builtins.typeOf prim == "string"
        then Result.result prim
        else Result.error "A nix string is needed to construct the String type"
      ;

      members = { self-type, ... }: {

        length = {

          type = Int;

          __description = ''
            Returns the length of the string.
          '';
          
          __functor = _: { self, ... }:
            let
              str = self.${self-type.uid}.prim;
            in
              builtins.stringLength str
            ;
        };
      };
    };
  };
}
