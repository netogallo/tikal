# This is a very low-level module which contains the minimum number of attributes needed
# to construct a Tikal universe with the corresponding sync scripts. In general, all Tikal
# modules will reduce to the attribtues defined in this module, which are then used
# to generate the sync scripts and the Tikal universe. Users are not expected to
# directly define/set options defined in this model. Rather, other modules will define
# high level options for users to use. These modules will translate the high level
# options into the options defined in this module.
{ config, lib, ... }:
let
  inherit (lib) types mkOption;
  imports = [
    ./config/tikal-storelock.nix
    ./universe/members.nix
    ./networks/tor.nix
    ./remote-access/ssh.nix
  ];
  script-type = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = ''
          A friendly name for the script. This value plays no role other than
          becoming part of the name of the files generated to include this script.
          In particular, the name of the python module which will be imported to
          run the script.
        '';
      };
      packages = mkOption {
        type = types.anything;
        description = ''
          This is the low-level attribute used to define hooks that are executed
          during the Tikal sync stage. This attribute is expected to be a function
          that accepts the following context as arguments:

            - The Tikal universe
          
          and produces a sync hook definition. A sync hook is a xonsh package
          definition (see 'write-packages' of lib/xonsh.nix) which should contain
          a package identified by the "name" attribute above. The package must
          export a function called "__main__" which will be called with the
          following arguments:

            - The Tikal sync context

          Generally speaking, one should not directly write this argument. See
          the "lib/sync/lib.nix" module for helper functions which provide
          simplified interfaces to add sync hooks.
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
