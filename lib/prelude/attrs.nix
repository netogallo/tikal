{ lib, test, trace, ... }:
let
  size = attrs: lib.length (lib.attrNames attrs);
  merge-disjoint = a: b:
    let
      result = a // b;
      disjoint = size result == (size a + size b);
    in
      if disjoint
      then result
      else
        throw "The sets '${trace.debug-print a}' and '${trace.debug-print b}' are not disjoint."
  ;
in
  test.with-tests
  {
    inherit size disjoint;
  }
  {
    tikal.prelude.attrs = {
      merge-disjoint = {
        "It throws when sets are not disjoint." = { _assert, ... }: _assert.all [
          (_assert.throws (merge-disjoint { a = 1; } { a = 2; b = 3; }))
        ];
      };
    };
  }
