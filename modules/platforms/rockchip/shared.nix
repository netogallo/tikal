/**
This module contains configuration which is common to all rockchip platforms.
*/
{ tikal, lib, ... }:
let
  inherit (tikal.xonsh) xsh;
  log = tikal.prelude.log.add-context { file = ./shared.nix; };
  uboot-installer-package = { uboot-image }: xsh.write-shell-script {
    name = "install_rockchip_uboot";
    script = ''
      import sys
      import json

      uboot_image = "${uboot-image}"

      # Read the bootloader spec from the
      # standard input.
      spec = json.load(sys.stdin.read())

      install_device = spec["config"]["bootDevice"]

      print(f"Flashing uboot to {install_device}.")

      dd f"if={uboot_image}" f"of={install_device}" bs=512 seek=64 conv=sync,fsync status=progress

      print(f"Flashing uboot to {install_device} completed.")
    '';
  };

  /**
  This function generates the installer used to flash uboot in rockchip systems. It accepts
  a package which produces a uboot image. The uboot image will be specific to the rockchip
  platform targeted in the installation.
  */
  uboot-installer = args:
    log.log-value
    "uboot-installer"
    "${uboot-installer-package args}"
  ;
in
  {
    config._module.args = {
      tikal-rockchip = {
        inherit uboot-installer;
      };
    };
  }
