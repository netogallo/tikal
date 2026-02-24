/**
This module builds the tikal nixos installer. This installer is
an automated script to install a nahual into a device. The
concrete implementation of the installer will vary from
platform to platform. As an example, aarch64 based systems
might use extlinux + uboot to start while amd64 systems might
use grub. The parameters for this installer can be adjusted
to accomodate both scenarios.
*/
{
  pkgs,
  universe,
  lib,
  tikal,
  nahual,
  tikal-config,
  tikal-flake-context,
  platform-name,
  ...
}:
let
  inherit (tikal) hardcoded;
  inherit (tikal.template) template template-nix;
  inherit (tikal.xonsh) xsh;
  log = tikal.prelude.log.add-context { file = ./tikal-installer.nix; };
  rootfs = {
    partuuid = "9ddbbf04-f472-4ba9-9142-245f8391decc";
    fsType = "btrfs";
  };
  bootfs = {
    partuuid = "716b6b6e-bb81-4c5b-ad7c-708dbf105dea";
    fsType = "ext4";
  };
  swapfs = {
    partuuid = "6299788d-486f-46b0-9092-95c629f7f771";
    fsType = "swap";
  };
  inherit (tikal-flake-context.nahuales.${nahual}.public.tikal-keys) tikal_main_pub;
  make-flake = config:
  let
    args = {
      inherit nahual;
      platform_system = config.platform-system;
      platform_module = config.platform-module;
      universe = universe.config.universe.id;
      universe_repository =
        if tikal-config.universe-repository == null 
        then
          log.log-warning
          ''
          No universe repository provided. Using flake root instead.
          It is recommended to provide a universe repository so the nahual
          can be updated by following the updates of that repository.
          ''
          tikal-config.flake-root
        else tikal-config.universe-repository
      ;

      rootfs_partuuid = rootfs.partuuid;
      rootfs_fs_type = rootfs.fsType;

      bootfs_partuuid = bootfs.partuuid;
      bootfs_fs_type = bootfs.fsType;

      swapfs_partuuid = swapfs.partuuid;

      # this is here to get the substitution in
      # the comment
      identifier = "<% identifier %>";
    };
  in
    template-nix
    ./tikal-installer/flake.template.nix
    args
  ;
  package = config:
  let
    vars = with pkgs; with config; {
      inherit nahual rootfs bootfs swapfs default-root-device
        default-boot-device bootloader-installer platform-name
        tikal_main_pub;
      inherit (hardcoded) tikal-decrypt-keys-directory
        tikal-decrypt-master-key-file;
      sgdisk = "${pkgs.gptfdisk}/bin/sgdisk";
      curl = "${pkgs.curl}/bin/curl";
      age = "${pkgs.age}/bin/age";
      flake = make-flake config;
    };
    script = template ./tikal-installer/install.xsh vars;
  in
    log.log-value "installer for ${platform-name}" (xsh.write-script-bin {
      name = "tikal-install";
      inherit script;
    })
  ;
in
  {
    inherit package;
  }
