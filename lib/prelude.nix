{ callPackage, ... }:
let
  do = callPackage ./prelude/do.nix {};
  debug-print = val:
    let
      toPretty = x:
        if builtins.isAttrs x then
          do.do [
            x
            "$>" builtins.mapAttrs (k: v: ''${k} = ${toPretty v}'')
            "|>" builtins.concatStringsSep ","
            "|>" (res: ''{ ${res} }'')
          ]
        else if builtins.isList x then
          "[ " + builtins.concatStringsSep ", " (map toPretty x) + " ]"
        else if builtins.isBool x || builtins.isInt x || builtins.isString x then
          builtins.toString x
        else if builtins.isFunction x then
          "<lambda>"
        else if builtins.isPath x then
          "<path: ${toString x}>"
        else if x == null
        then "null"
        else
          "<unknown>"
      ;
    in toPretty val
  ;
in
  {
    inherit debug-print;
    inherit (do) do;
    trace = msg: value: builtins.trace (debug-print msg) value;
  }
