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
      lib.concatStringsSep " " (lib.mapAttrsFlatten mapper ctx)
  ;
  
  trace-log = { level, message, context, include-value }: value:
    let
      context' = write-context context;
      value' = debug-print value;
      log =
        {
          inherit level message;
        } //
        (
          if include-value && value' != ""
          then { value = value'; }
          else { value = ""; }
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
    
    log-internal = { level, message, include-value, extra-context ? {} }: 
      if level > log-level
      then lib.id
      else
        trace-log
        {
          inherit level message include-value;
          context = context // extra-context // { inherit log-level; };
        }
    ;

    log-message =
      lib.makeOverridable
      ({ include-value, level }: msg-or-ctx:
        if lib.typeOf msg-or-ctx == "string"
        then value:
          log-internal {
            inherit level include-value;
            message = msg-or-ctx;
          }
          value
        else message: value:
          log-internal {
            inherit level include-value message;
            extra-context = msg-or-ctx;
          }
          value
      )
      { include-value = false; level = level.debug; }
    ;

    log-info = log-message.override { level = level.info; };
    log-debug = log-message.override { level = level.debug; };
    log-warning = log-message.override { level = level.warning; };
    log-error = log-message.override { level = level.error; };

    log-value = log-message.override { level = level.debug-verbose; include-value = true; };

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
