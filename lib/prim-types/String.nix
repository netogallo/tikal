{
  tikal
}:
{
  module = "Tikal.Nix.Types";

  new-prim = { lib, result, ... }: prim-value:
    if lib.isType "string" prim-value
    then result.success prim-value
    else result.error "Cannot create a string instance from a non-string value."
  ;

  members = { self-type }: {
  };
}
