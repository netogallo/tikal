{ lib, nahual, universe, nahual-config, ... }:
let
  inherit (universe.config) tikal-dir;
  module = { config, ... }: {
    options = {
      tikal.meta = {
        nahual = mkOption {
          type = types.string;
          description = ''
          The name of the nahual. This option cannot be changed. However, it can
          be accessed by other nixos modules for customization.
          '';
          default = nahual;
        };

        tikal-dir = mkOption {
          type = types.string;
          description = ''
          The relative path from the universe's flake where the tikal
          configuration folder of this universe is located. This option is
          for information purposes and cannot be changed.
          '';
          default = tikal-dir;
        };
      };
    };

    config = {
      assertions = [
        {
          assertion = config.tikal.meta.nahual == nahual;
          message = "The value cannot be changed. It is metdata.";
        }
        {
          assertion = config.tikal.meta.tikal-dir == tikal-dir;
          message = "The value cannot be changed. It is metadata.";
        }
      ];
    };
  };
in
  {
    inherit module;
  }
