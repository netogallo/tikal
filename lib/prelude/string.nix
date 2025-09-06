{ lib, ... }:
let
  inherit (lib) strings;
  head = strings.substring 0 1;
  tail = strings.substring 1 (-1);
  elem = pred: str: lib.elem pred (lib.stringToCharacters str);
  all = pred: str: lib.all pred (lib.stringToCharacters str);
in
  {
    inherit head tail elem all;
  }
