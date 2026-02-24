# This is the module definition for the sync component of Tikal. The purpose
# of this module is to generate the sync script for a universe. Other tikal
# modules will provide parts which will be combined into the final sync
# script.
{ lib, tikal, ... }:
let
  inherit (lib) types mkOption;
  log = tikal.prelude.log.add-context { file = ./main.nix; };
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
  imports = [
    ./context.nix
    ./config/store-lock.nix
    ./config/secrets.nix
    ./network/tor.nix
    ./remote-access/ssh.nix
  ];
  options = {
    sync.scripts = mkOption {
      type = types.listOf script-type;
      default = [];
      description = ''
        This option is meant to contain all the scripts that
        will eventually become part of the main sync script.
        This is where other nixos modules can include scripts
        meant to add secrets into the various nahuales.
      '';
    };
  };
}
