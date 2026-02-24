{ tikal-sync-context, tikal-flake-context, lib, ... }:
let
  inherit (lib) mkOption types;
in
  # Todo: This is not a good approach to provide the context. It would
  # be much better if all the options were explicitly laid out and
  # it should be refactored accordingly.
  {
    options = {
      tikal.context = {
        sync = mkOption {
          description = ''
            A set of constants derived from the universe and configuration
            used by the sync scripts to determine where to place their
            output.
          '';
          type = types.anything;
          readOnly = true;
          default = tikal-sync-context;
        };

        flake = mkOption {
          description = ''
            A set of constants derived from the universe configuration
            which are used when building the objects exposed by Tikal
            flakes.
          '';
          type = types.anything;
          readOnly = true;
          default = tikal-flake-context;
        };
      };
    };
  }
