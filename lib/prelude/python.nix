{ lib, ... }:
let
  store-path-to-python-identifier = inp:
    "_" + lib.replaceStrings [ builtins.storeDir "." "-" ] [ "" "__" "_" ] inp
  ;
  valid-chars =
    let
      alpha-lower = "abcdefghijklmnopqrstuvwxyz";
      alpha = "${alpha-lower}${lib.strings.toUpper alpha-lower}";
      numbers = "123456789";
      other = "_";
    in
      {
        valid-body = lib.stringToCharacters "${alpha}${numbers}${other}";
        valid-start = lib.stringToCharacters "${alpha}${other}";
      }
  ;
  is-valid-python-identifier = string:
    let
      head-valid = !(lib.elem (lib.strings.head string) valid-chars.valid-start);
      body = lib.stringToCharacters (lib.strings.tail string);
      body-valid = lib.all (c: !(lib.elem c valid-chars.valid-body)) body;
    in
      head-valid && body-valid
  ;
in
  {
    inherit store-path-to-python-identifier is-valid-python-identifier;
  }
