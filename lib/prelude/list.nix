{ lib, test, ... }:
let
  inherit (test) with-tests;
  take-end = n: items:
    let
      size = lib.size items;
      q = size - n;
    in
      lib.sublist 0 q items
  ;
in
  with-tests
  {
    inherit take-end;
  }
  {
    prelude.list.take-end = {
      "it should take elements 'n' from the end" = { _assert, ... }: [
        _assert.eq [ 4 5 ] (take-end 2 [ 1 2 3 4 5])
        _assert.eq [] (take-end 0 [ 1 2 3 4 5])
      ];
      "it should take all elements if n >= length" = { _assert, ... }: [
        _assert.eq [ 1 ] (take-end 5 [ 1 ])
        _assert.eq [] (take-end 5 [])
      ];
    };
  }
