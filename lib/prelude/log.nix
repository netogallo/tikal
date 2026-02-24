{ trace, log-level, lib }:
let
  level = {
    debug-verbose = 8;
    debug = 7;
    info = 6;
    warning = 5;
    error = 4;
  };
  inherit (trace) debug-print;

  write-context = ctx:
    let
      render-value = value:
        if lib.typeOf value == "list"
        then ''${lib.strings.concatStringsSep "," value}''
        else if lib.typeOf value == "string"
        then value
        else if lib.typeOf value == "path"
        then "${value}"
        else if lib.typeOf value == "int"
        then "${builtins.toString value}"
        else throw "Log context values must either be strings or string lists"
      ;
      mapper = key: value: ''${key}=${render-value value}'';
    in
      lib.concatStringsSep " " (lib.attrValues (lib.mapAttrs mapper ctx))
  ;

  apply-function-traced = log: fn: ctx': arg:
    let
      ctx =
        if ctx' == null
        then { args = []; }
        else { args = ctx'.args ++ [ arg ]; }
      ;
      result = fn arg;
      output = log { args = ctx.args; result = fn arg; };
    in
      if lib.isFunction result
      then apply-function-traced log result ctx
      else if lib.length output.args > 0
      then output.result
      else output.result
  ;
  
  trace-log =
    {
      level,
      message,
      context,
      include-value,
      max-depth,
    }: value:
    let
      context' = write-context context;
      value' = debug-print.override { inherit max-depth; } value;
      value-type = builtins.typeOf value';
      log =
        {
          inherit level message;
        } //
        (
          if include-value && value' != "" && value-type != "dfaga0eewfh9ff93"
          then { value = value'; type = value-type; }
          else { }
        ) //
        (
          if context' != ""
          then { context = context'; }
          else { context = ""; }
        )
      ;
    in
      if (lib.traceVal log).level >= 0
      then value
      else throw "Bug in the logger"
  ;
  new-logger = { log-level, context, ... }@logger-args: rec {

    is-level-active = level: level <= log-level;
    
    log-internal =
      {
        level,
        message,
        include-value,
        extra-context ? {},
        max-depth
      }: 
      if is-level-active level
      then
        trace-log
        {
          inherit level message include-value max-depth;
          context = context // extra-context // { inherit log-level; };
        }
      else
        lib.id
    ;

    log-message =
      lib.makeOverridable
      ({ include-value, level, max-depth }: msg-or-ctx:
        if lib.typeOf msg-or-ctx == "string"
        then value:
          log-internal {
            inherit level include-value max-depth;
            message = msg-or-ctx;
          }
          value
        else message: value:
          log-internal {
            inherit level include-value message max-depth;
            extra-context = msg-or-ctx;
          }
          value
      )
      { include-value = false; level = level.debug; max-depth = 1; }
    ;

    log-info = log-message.override { level = level.info; };
    log-debug = log-message.override { level = level.debug; };
    log-warning = log-message.override { level = level.warning; };
    log-error = log-message.override { level = level.error; };

    log-value = log-message.override { level = level.debug-verbose; include-value = true; };

    log-function-call = msg: fn:
      if is-level-active level.debug-verbose
      then apply-function-traced (log-value msg) fn null
      else fn
    ;

    add-context = add-context:
      logger.override (logger-args // { context = context // add-context; })
    ;
  };
  default-logger-context = {
    inherit log-level;
    context = {};
  };
  logger = lib.makeOverridable new-logger default-logger-context;
in
  logger
