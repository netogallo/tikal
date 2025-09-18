{ lib, ... }:
let
  inherit (lib) strings;
  head = strings.substring 0 1;
  tail = strings.substring 1 (-1);
  elem = pred: str: lib.elem pred (lib.stringToCharacters str);
  all = pred: str: lib.all pred (lib.stringToCharacters str);
  is-suffix-of = suffix: str:
    let
      str-len = strings.stringLength str;
      suffix-len = strings.stringLength suffix;
      candidate = strings.substring (str-len - suffix-len) suffix-len str;
    in
      str-len >= suffix-len && candidate == suffix
  ;
in
  {
    inherit head tail elem all is-suffix-of;
  }
