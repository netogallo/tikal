{
  universe,
  lib,
  nixos-modules,
  nixpkgs,
  pkgs,
  ...
}:
let
  host-platform = pkgs.stdenv.system;

  /** The qemu-vm function will create a nixos configuration that
  lanuges a minimalistic virtual machine corresponding to a nahual.
  This is mostly offered as a convenience meant for testing nahuales.
  */
  qemu-vm = nahual: nixosModule:
    let
      vm-config = { config, pkgs, ... }:
        let
          tikal-user = config.tikal.meta.nixos-context.tikal-user;
        in
        {
          imports = [
            ../modules/virtualization/tikal-qemu.nix
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
        modules = [
          vm-config
          { config.nixpkgs.hostPlatform = host-platform; }
        ];
      };
      package = nixosSystem.config.system.build.tikal.vm.qemu;
      app-name = "tikal-vms-${nahual}-qemu";
    in
      {
        packages.${app-name} = package;
        apps.${app-name} = {
          type = "app";
          program = "${nixosSystem.config.system.build.tikal.vm.qemu}/bin/run-qemu";
        };
      }
  ;
in
  lib.foldAttrs (s: vm: s // vm) {} (lib.attrValues (lib.mapAttrs qemu-vm nixos-modules))
