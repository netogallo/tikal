{ lib, match, test-filters, log, ... }:
let
  inherit (lib) strings;
  glob-to-re = strings.replace [ "." "*" ] [ "\\." ".*" ];
  process-filter = filter:
    match filter [
      match.isFunction (f: f)
      match.isString (s: s': s == s')
      ({ glob }: strings.match (glob-to-re filter))
      match.otherwise (v: throw "Value '${lib.typeOf v}' not supported as a test filter!")
    ]
  ;
in
  {
  }
