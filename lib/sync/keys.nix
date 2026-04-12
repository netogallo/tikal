{ sync-module, openssh, age, expect, tikal, ... }:
let
  inherit (tikal.xonsh) xsh;
  inherit (tikal.template) template;
in
{
  script = xsh.write-script {
    name = "keys.xsh";
    vars = {
      inherit (sync-module.config.tikal.context) nahuales;
      inherit (sync-module.config.tikal.sync.identities) nahual-master-keys;
    };
    script = { vars, ... }: template ./keys.xsh { inherit vars; };
  };
}

