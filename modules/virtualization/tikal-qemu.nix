{ pkgs, modulesPath, config, ... }:
let
  inherit (config.tikal.meta) nahual tikal-dir;
  run-qemu =
    pkgs.writeScript
    "run-qemu"
    ''
      password_file="$PWD/${tikal-dir}/private/${nahual}/keys/id_tikal.pass"

      if [ -f "$password_file" ]; then
        password=$(cat "$password_file")
        export QEMU_KERNEL_PARAMS="tikal.master-password=$password"
      fi

      ${config.system.build.vm}/bin/run-${config.system.name}-vm
    ''
  ;
in
  {
    imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
    config.system.build.tikal.vm.qemu = run-qemu;
  }
