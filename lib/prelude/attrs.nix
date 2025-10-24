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
  map-attrs-with =
    lib.makeOverridable(
      { strict }: mappings: attrs:
      let
        present-mappings =
          lib.filterAttrs
            (
              name: fn:
              if strict && !lib.hasAttr name attrs
              then throw ''
                The set:

                  ${trace.debug-print attrs}

                is missing the attribute "${name}"
              ''
              else lib.hasAttr name attrs
            )
            mappings
        ;
      in
        attrs //
        (lib.mapAttrs (name: fn: fn name attrs.${name}) present-mappings)
      )
      { strict = false; }
  ;
in
  test.with-tests
  {
    inherit size merge-disjoint map-attrs-with;
  }
  {
    tikal.prelude.attrs = {
      merge-disjoint = {
        "It throws when sets are not disjoint." = { _assert, ... }: _assert.all [
          (_assert.throws (merge-disjoint { a = 1; } { a = 2; b = 3; }))
        ];
      };

      map-attrs-with = {
        "It maps the specified attributes according to the input." = { _assert, ... }:
          let
            input = { x = 1; y = 2; z = 3; };
            f1 = _: x: x + 2;
            f2 = _: x: x * 3;
          in
            _assert.all [
            (_assert.eq (input // { x = f1 "x" input.x; y = f2 "y" input.y; }) (map-attrs-with { x = f1; y = f2; } input))
            (_assert.eq input (map-attrs-with { w = f1; } input))
          ]
        ;
        "It fails when attributes are missing in 'strict' mode." = { _assert, ... }:
          _assert.all [
            (_assert.throws (map-attrs-with.override { strict = true; } { w = _: x: x + 2; } { x = 5; }))
          ]
        ;
      };
    };
  }
