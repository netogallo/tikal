{ callPackage, lib, do, ... }:
let
  inherit (lib.customisation) makeOverridable;
  strings = lib.strings;
  debug-print-defaults = { max-depth = 10; };
  debug-print-overridable = { max-depth }: val:
    let
      toPretty = d': x:
        let
          d = d' + 1;
        in
        if d > max-depth
        then "<...>"
        else if builtins.isAttrs x then
          do.do [
            x
            "$>" lib.mapAttrs (k: v: ''${k} = ${toPretty d v}'')
            "|>" lib.attrValues
            "|>" lib.concatStringsSep ", "
            "|>" (res: ''{ ${res} }'')
          ]
        else if builtins.isList x then
          "[ " + builtins.concatStringsSep ", " (map (toPretty d) x) + " ]"
        else if lib.isBool x || lib.isInt x || lib.isString x then
          strings.toJSON x
        else if builtins.isFunction x then
          "<lambda>"
        else if builtins.isPath x then
          "<path: ${toString x}>"
        else if x == null
        then "<null>"
        else
          "<unknown>"
      ;
    in toPretty 0 val
  ;
  debug-print = makeOverridable debug-print-overridable debug-print-defaults;
  trace-overridable = args: msg: value: builtins.trace (debug-print-overridable args msg) value;
  trace = makeOverridable trace-overridable debug-print-defaults;
  trace-value = value: trace value value;
  throw-print = context: msg:
    let
      mk-sub = key: value: { key = "{${key}}"; value = debug-print value; };
      subs = lib.mapAttrs' mk-sub context;
      keys = lib.mapAttrsToList (k: _: k);
      vals = lib.mapAttrsToList (_: v: v);
    in
      throw (lib.replaceStrings keys vals)
  ;
in
  {
    inherit debug-print trace trace-value throw-print;
  }
