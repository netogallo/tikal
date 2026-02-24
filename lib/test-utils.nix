{ universe-scope, tikal-config, ... }:
let
  original-tikal-config = tikal-config;
  mocks = {

    # This function builds a mock universe to be used for
    # testing purposes. It accepts custom configuration
    # as well as a universe spec to produce the resulting
    # universe.
    universe = { tikal-config, universe }@inputs:
    let
      config-defaults = {
        inherit (original-tikal-config) log-level test-filters;
      };
      test-universe-scope = universe-scope.overrideScope(self: super: {
        tikal-config = config-defaults // tikal-config;
        universe-spec = universe;
      });
    in
      test-universe-scope.universe
    ;
  };
in
  {
    inherit mocks;
  }
