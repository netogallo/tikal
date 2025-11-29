{
  universe,
  lib,
  tikal-flake,
  system,
  nixos-modules,
  nixpkgs,
  ...
}:
let
  qemu-vm = nahual: nixosModule:
    let
      vm-config = { config, pkgs, ... }:
        let
          tikal-user = config.tikal.${universe.universe-module.module.config.universe.id}.meta.tikal-user;
        in
        {
          imports = [
            "${tikal-flake}/modules/virtualization/tikal-qemu.nix"
            nixosModule
          ];

          config = {
            boot.loader.grub.enable = false;
		        networking.useDHCP = true;

            # The password is set to tikal for the VM
            users.users.${tikal-user}.hashedPassword = "$y$j9T$Ij.zgsiQ9UbG805vuIjz0/$qiZCBxun/3VJrAic6AGusQTlX4VN2W.Mp4LrFPrFZ6B";

            system.name = config.tikal.meta.nahual;
            networking.hostName = config.tikal.meta.nahual;
          };
        }
      ;
      nixosSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ vm-config ];
      };
    in
      {
        type = "app";
        program = "${nixosSystem.config.system.build.tikal.vm.qemu}/bin/run-qemu";
      }
  ;
  make-vm-app = nahual: nixosConfiguration: {
    qemu = qemu-vm nahual nixosConfiguration;
  };
in
  {
    vms = lib.mapAttrs make-vm-app nixos-modules;
  }
