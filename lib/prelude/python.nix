{ lib, string, ... }:
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
  is-valid-python-identifier = identifier:
    let
      head-valid = !(lib.elem (string.head identifier) valid-chars.valid-start);
      body = string.tail identifier;
      body-valid = string.all (c: !(lib.elem c valid-chars.valid-body)) body;
    in
      head-valid && body-valid
  ;
in
  {
    inherit store-path-to-python-identifier is-valid-python-identifier;
  }
