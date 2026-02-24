{ lib, universe, ... }:
let
  inherit (lib) mkOption types;
in
  {
    options = {
      tikal.context = mkOption {
        description = ''
          This value contains a collection of constants which are derived
          from the tikal universe as well as configuration options. Most
          notably, this contains the paths which the sync scripts are
          meant to use to write their output.
        '';
        readOnly = true;
        type = types.anything;
        default = universe.config.tikal.context.sync;
      };
    };
  }
