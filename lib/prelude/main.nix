{ callPackage, lib, ... }:
let
  inherit (lib.customisation) makeOverridable;
  strings = lib.strings;

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
  drop-store-prefix =
    makeOverridable
    ({ strict }: path:
      if strict && !(lib.isStorePath path)
      then throw "The value '${path}' must be a store path."
      else lib.replaceStrings ["${builtins.storeDir}/"] [""] path
    )
    { strict = false; }
  ;
  is-prefix = prefix: str:
    let
      len = lib.stringLength prefix;
      result = strings.substring 0 len str == prefix;
    in
      result
  ;
  partition = tagger: values:
    let
      mapper = value: { ${tagger value} = value; };
      joiner = item: items: [item] ++ items;
    in
      lib.foldAttrs joiner [] (map mapper values)
  ;
  fold-attrs-recursive-impl = path: acc: initial: attrs:
    let
      this-acc = state: key:
        let
          value = attrs.${key};
          full-key = path ++ [key];
        in
          if lib.isAttrs value
          then fold-attrs-recursive full-key acc state value
          else acc state full-key value
      ;
    in
      lib.fold this-acc initial (lib.attrNames attrs)
  ;
  fold-attrs-recursive = fold-attrs-recursive-impl [];
in
  {
    inherit store-path-to-key drop-store-prefix is-prefix
      partition fold-attrs-recurisve;
  }
