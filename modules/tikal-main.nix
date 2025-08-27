{ config, lib, ... }:
let
  inherit (lib) types mkOption;
  imports = [
    ./universe/members.nix
    ./networks/tor.nix
    ./remote-access/ssh.nix
  ];
  script-type = types.submodule {
    options = {
      uid = mkOption {
        type = types.string;
        description = ''
          A unique identifier for this script. This identifier should be derived
          from a store path corresponding to the script as it is used to determine
          if this script has been run.
        '';
      };
      text = mkOption {
        type = types.anything;
        description = ''
          This type is a function that produces the script that is
          to be executed as part of the sync step. It will be given
          as an argument a context which contains:
            - The tikal universe

          It can use that context to produce the script.
        '';
      };
    };
  };
in
{
  inherit imports;
  options = {
    tikal.sync.scripts = mkOption {
      type = types.listOf script-type;
      default = [];
      description = ''
        This option is meant to contain all the scripts that
        will eventually become part of the main sync script.
        This is where other nixos modules can include scripts
        meant to add secrets into the various nahuales.
      '';
    };

    tikal.build.public = mkOption {
      type = types.attrsOf (types.attrsOf types.unspecified);
      default = {};
      description = ''
        The purpose of this options is to collect public files which are meant
        to be shared accross nahuales beloning to the same universe. In practice
        this often means public keys. The structure of this object is meant to
        be: "tikal.build.public.[<nahual>].[<secret name>] = <arbitrary value>".
      '';
    };

    tikal.build.modules = mkOption {
      type = types.attrsOf (types.listOf types.unspecified);
      default = lib.mapAttrs (_name: _value: []) config.nahuales;
      description = ''
        This option is meant to collect the list of modules that
        are to be included by each of the modules that define a
        nahual. Tikal modules are to use this option to add
        all of the modules that each nahual needs.
      '';
    };

  };
  config = {};
}
