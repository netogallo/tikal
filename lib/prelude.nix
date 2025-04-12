{ ... }:
rec {
  pipe = {
    _done = false;
    _state = x: x;
    __functor = self: fn:
      if self._done
      then self._state fn
      else if fn == "<|"
      then self // { _done = true; }
      else self // { _state = arg: self._state (fn arg); }
    ;
  };
  debug-print = val:
    let
      toPretty = x:
        if builtins.isAttrs x then
          pipe
          (res: ''{ ${res} }'')
          (builtins.concatStringsSep ", ")
          (builtins.attrValues)
          (builtins.mapAttrs (k: v: ''${k} = ${toPretty v}''))
          "<|" x
        else if builtins.isList x then
          "[ " + builtins.concatStringsSep ", " (map toPretty x) + " ]"
        else if builtins.isBool x || builtins.isInt x || builtins.isString x then
          builtins.toString x
        else if builtins.isFunction x then
          "<lambda>"
        else if builtins.isPath x then
          "<path: ${toString x}>"
        else
          "<unknown>"
      ;
    in toPretty val
  ;
  trace = msg: value: builtins.trace (debug-print msg) value;
}
