{ callPackage, lib, ... }:
let
  inherit (lib.customisation) makeOverridable;
  strings = lib.strings;
  do = callPackage ./prelude/do.nix {};
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
  # I have no idea why nix has the limitation that
  # store paths cannot be used as keys in a set.
  # Especially because one can fool nix and achieve
  # that anyways. This function fools nix to allow
  # a given store path to be used as key. As a
  # convenience, it drops the /nix/store/ prefix.
  store-path-to-key = store-path:
    let
      impossible-error = throw ''
        This should not happen. If it does, it means that the code in
        tikal/prelude.nix needs an update. Essentially, it means that
        a nix store paths has characters that the code did not expect
        at the point of writing.

        The input was ${store-path}
      '';
      alphabet = lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz1234567890-.";
      # This function replaces the 'bad' characters that come from a string produced
      # from a store path and repalces them with 'good' characters that come from
      # the string defined above. Nix seems to be doing some sort of dodgey tagging of values
      # so this seemingly pure function that should not modify the input is totally impure.
      fool-nix = bad-char: lib.findSingle (good: bad-char == good) impossible-error impossible-error alphabet;
    in
      # Cannot use do because the implementation uses strings in the array as set keys.
      lib.concatStrings (
        lib.map fool-nix (
          lib.stringToCharacters (
            lib.replaceStrings ["${builtins.storeDir}/"] [""] store-path
      )))
  ;
  store-path-to-python-identifier = inp:
    "_" + lib.replaceStrings [ builtins.storeDir "." "-" ] [ "" "__" "_" ] inp
  ;
  drop-store-prefix =
    makeOverridable
    ({ strict }: path:
      if strict && !(lib.isStorePath path)
      then throw "The value '${path}' must be a store path."
      else lib.replaceStrings ["${builtins.storeDir}/"] [""] path
    )
    { strict = false; }
  ;
  trace-overridable = args: msg: value: builtins.trace (debug-print-overridable args msg) value;
  trace = makeOverridable trace-overridable debug-print-defaults;
  trace-value = value: trace value value;
  is-prefix = prefix: str:
    let
      len = lib.stringLength prefix;
      result = strings.substring 0 len str == prefix;
    in
      trace { inherit prefix str result; } result
  ;
in
  {
    inherit debug-print store-path-to-key store-path-to-python-identifier
      drop-store-prefix trace trace-value is-prefix;
    inherit (do) do;
  }
