{ lib, config, ... }:
let
  inherit (lib) types mkOption;
in
{
  imports = [
    ./context.nix
    ./members.nix
    ./network/tor.nix
    ./remote-access/ssh.nix
  ];
  options = {

    tikal-user = lib.mkOption {
      description = ''
        This is the admin user of the universe. Every nahual will have this
        account which will be responsible for performing system mantainance
        among other things.
      '';
      default = "tikal-root";
      type = lib.types.str;
    };

    universe = {
      id = mkOption {
        description = ''
          The name of the universe being defined.
        '';
        default = "tikal-universe";
        type = types.str;
      };
    };

    tikal.build.nahuales-nixos-modules = mkOption {
      type = types.attrsOf (types.listOf types.unspecified);
      default = lib.mapAttrs (_name: _value: []) config.nahuales;
      description = ''
        This option is meant to collect the list of modules that
        are to be included by each of the modules that define a
        nahual. Tikal modules are to use this option to add
        all of the modules that each nahual needs.
      '';
    };

    tikal.build.sync-modules = mkOption {
      type = types.listOf types.unspecified;
      default = [];
      description = ''
        This option gathers a list of modules that will be used to
        generate the "sync" module. When the universe module
        is evaluated, it should produce a set of sync modules which
        then will be evaluated to produce the sync script. While
        the universe module is meant to be platform agnostic, the
        sync module will be platform specific to the platform that
        will be running the sync script.
      '';
    };
  };
}
