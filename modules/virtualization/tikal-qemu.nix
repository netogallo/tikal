{ pkgs, modulesPath, config, ... }:
let
  inherit (config.tikal.meta.apps-context) nahual nahual-private;
  run-qemu =
    pkgs.writeShellApplication
    {
      name = "run-qemu";
      text = 
        ''
        password_file="$PWD/${nahual-private}/keys/id_tikal.pass"
        if [ -f "$password_file" ]; then
          password=$(cat "$password_file")
          export QEMU_KERNEL_PARAMS="tikal.debug.master-key=$password"
        fi
        ${config.system.build.vm}/bin/run-${config.system.name}-vm
        ''
      ;
    }
  ;
in
  {
    imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
    config.system.build.tikal.vm.qemu = run-qemu;
  }
