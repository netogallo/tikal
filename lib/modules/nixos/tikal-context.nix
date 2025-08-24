{ nahual, nahual-modules, lib, ... }:
let
  tikal-context = {};
  mk-module = module:
    if lib.isFunction module
    then (args: module (tikal-context // args))
    else module
  ;
in
{
  modules = lib.map mk-module nahual-modules;
}
