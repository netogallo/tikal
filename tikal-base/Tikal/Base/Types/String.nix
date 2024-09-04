{
  __description = ''
  The String type represents a character string along with the various operations
  that can be performed on a string. This type directly wraps around Nix's own
  builtin string.
  '';

  new-prim = {

    __description = ''
    This function takes the primitive Nix value and validates that it is indeed a string.
    It returns either the string or an error message. This function should never fail
    and simply return an error if the value cannot be interpreted as a string.
    '';

    __functor = { lib, result, ... }: prim-value:
      if lib.isType "string" prim-value
      then result.success prim-value
      else result.error "Expected a string, but got a different type."
    ;

  };
}
