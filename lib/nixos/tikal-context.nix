{ nahual, nahual-modules, lib, universe, tikal-secrets, ... }:
let
  tikal-context = {
    inherit tikal-secrets;
  };
  mk-module = module:
    if lib.isFunction module
    then (args: module (tikal-context // args))
    else module
  ;
in
{
  modules = lib.map mk-module nahual-modules;
}
