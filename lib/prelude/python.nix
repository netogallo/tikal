{ lib, string, test, ... }:
let
  store-path-to-python-identifier = inp:
    "_" + lib.replaceStrings [ builtins.storeDir "." "-" ] [ "" "__" "_" ] inp
  ;
  valid-chars =
    let
      alpha-lower = "abcdefghijklmnopqrstuvwxyz";
      alpha = "${alpha-lower}${lib.strings.toUpper alpha-lower}";
      numbers = "1234567890";
      other = "_";
    in
      {
        valid-body = lib.stringToCharacters "${alpha}${numbers}${other}";
        valid-start = lib.stringToCharacters "${alpha}${other}";
      }
  ;
  is-valid-python-identifier = identifier:
    let
      head-valid = lib.elem (string.head identifier) valid-chars.valid-start;
      body = string.tail identifier;
      body-valid = string.all (c: lib.elem c valid-chars.valid-body) body;
    in
      head-valid && body-valid
  ;
in
  test.with-tests
  {
    inherit store-path-to-python-identifier is-valid-python-identifier;
  }
  {
    prelude.python = {
      is-valid-python-identifier = {
        "it should accept valid python identifiers" = { _assert, ... }: _assert.all [
          (_assert.true (is-valid-python-identifier "a_good_python_identifier_66642"))
          (_assert.true (is-valid-python-identifier "_also_good"))
          (_assert.true (is-valid-python-identifier "tikal_host_onion_service_b4baeb13b0c5c63bf9cd81d8bea1a0cae682a598b572a17db0ff75fe593d1300"))
          (_assert.true (is-valid-python-identifier "__init__"))
        ];
        "it should reject invalid python identifieres" = { _assert, ... }: _assert.all [
          (_assert.false (is-valid-python-identifier "this-is-not valid"))
          (_assert.false (is-valid-python-identifier "66642_cannot_start_with_int"))
        ];
      };
    };
  }
