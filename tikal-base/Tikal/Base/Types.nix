{
  __description = ''
    This module contains the core types that are used throughout Tikal to describe
    system configurations.
  '';

  __functor = self: { type, ... }: rec {

    Int = type {

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

    String = type {

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
          
          __functor = { self, ... }: builtins.stringLength self.__prim;

        };
      };
    };
  };
}
