{ lib, ... }
let
  stages = {
    init = 0;
    semantic-op-build = 1;
  };
  initial-state = {
    result = [];
    state = states.init;
    semantic-op = null;
    semantic-args = null;
    semantic-argc = null;
  };
  acc =
    { lift-to-semantic-op }:
    { result, stage, semantic-op, semantic-args, semantic-argc }@state:
    next:
    let
      is-semantic-op = lib.isAttrs next && lib.hasAttr "__argc" next;

      next-op =
        if is-semantic-op next
        then next
        else lift-to-semantic-op next
      ;

      semantic-op-argc = next-op.__argc;

      semantic-op-init0 = {
        value = next-op;
        args = [];
      };

      semantic-op-init0-result =
        lib.throwIfNot (stage = stages.init)
        "Bug in the code, stage expected to be init"
        (
          state //
          {
            result = result ++ [ semantic-op-init0 ];
          }
        )
      ;

      semantic-op-init-result =
        state //
        {
          semantic-op = next-next-op;
          semantic-args = [];
          semantic-argc = semantic-op-argc;
          stage = stages.semantic-op-build;
        }
      ;
      semantic-op-apply-result =
        state //
        {
          semantic-op = semantic-op next;
          semantic-args = semantic-args ++ [ next ];
          semantic-argc = semantic-argc - 1;
        }
      ;
      semantic-op-complete = {
        value = semantic-op next;
        args = semantic-args ++ [ next ];
      };
      semantic-op-complete-result =
        state //
        {
          stage = stages.init;
          result = result ++ [ semantic-op-complete ];
          semantic-args = null;
          semantic-op = null;
          semantic-argc = null;
        }
      ;
    in
      # If the stage is init and we get a semantic operation
      # which takes no argments, the semantic operation is
      # absorbed into the results and the stage remains init
      if stage == stages.init && semantic-op-argc == 0
      then semantic-op-init0-result
      # If the state is initial and the value is a 
      # semantic function, we initialize the collection stage.
      # The number of arguments the semantic operation needs
      # is determined and subsequent elements in the array
      # become arguments of the semantic operation.
      if stage == stages.init
      then semantic-op-init-result

      # If the state is semantic-op-build and the semantic argument
      # count is greater than zero, it means the aguments for the
      # semantic operation are being collected. This simply appends
      # an additional argument to the semantic operation.
      else if stage == stages.semantic-op-build && semantic-argc > 1
      then semantic-op-apply-result

      # The last option is that no more arguments are needed for
      # the semantic operation. This means the semantic operation
      # has completed. It needs to be added to the results array.
      else if stage == stages.semantic-op-build && semantic-argc == 1
      then semantic-op-complete-result
      else throw ''
        This is a bug in the code. The control-flow should never
        reach this point as all possible alternatives should be
        covered by the if-statements above.
      ''
  ;
  reduce = config: arr:
    let
      result = lib.foldl (acc config) initial-state arr;
    in
      if result.stage != stages.init
      then throw ''
        Invalid expression was provided. All semantic operations
        must have been reduced before the expression completes.
      ''
      else result.result
  ;
  semantic-op = { name, argc, op }:
    {
      __name = name;
      __argc = argc;
      __functor = self: op;
    }
  ;
in
  {
    inherit reduce;
  }
