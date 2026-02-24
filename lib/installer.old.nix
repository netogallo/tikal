{
  universe,
  universe-repository,
  tikal,
  lib,
  pkgs,
  nixpkgs,
  callPackage,
  tikal-scope,
  ...
}:
let
  inherit (tikal) prelude;
  inherit (tikal.platforms) platforms;
  inherit (tikal.xonsh) xsh;
  inherit (tikal.prelude.template) template;

  log = prelude.log.add-context { file = ./installer.nix; };
  nahuales = universe.flake.config.nahuales;
  installer-module-base = { pkgs, ... }: {
    config = {
      system.name = "tikal-installer";
      system.stateVersion = "25.05";
      environment.systemPackages = with pkgs; [
        gptfdisk
        openssh
        git
      ];
      networking.networkmanager.enable = true;
      networking.wireless.enable = false;
    };
  };
  partitions = {
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
  };
  to-sd-install-image = { nahual, nahual-context, platform }: disk-image:
    let
      name = "tikal-installer-${nahual}-${platform.name}";
      programs = with pkgs; {
        losetup = "${util-linux}/bin/losetup";
        kpartx = "${multipath-tools}/bin/kpartx";
      };
      install-script = xsh.write-script-bin {
        inherit name;
        vars = {
          inherit nahual;
          disk-image = "${disk-image}/sd-image/${disk-image.name}";
          ssh-private-key = nahual-context.private.tikal-keys.tikal_main;
          ssh-public-key = nahual-context.public.tikal-keys.tikal_main_pub;
          output-image-name = "${name}.img";
          image-root-partition = "p2";
        };
        script = { vars, ... }:
          template
          ./installer/make-installation-media.xsh
          (vars // programs)
        ;
      };
      program = pkgs.writeShellScript
        name
        ''
        echo "Root access is needed to create the installation media. Running sudo."
        sudo ${install-script}/bin/${name}
        ''
      ;
    in
    {
      type = "app";
      program =
        log.log-debug
        { installer = "${install-script}/bin/${name}"; }
        "make installation media"
        "${program}"
      ;
    }
  ;
  finalize-install-media-script = args: { sd-image }:
    {
      sd-image = to-sd-install-image args sd-image;
    }
  ;
  create-installer = { nahual, nahual-context, platform }@args:
    let
      installer-program =
        callPackage
        ./installer/nahual-installer.nix
        {
          inherit tikal-scope nixpkgs nahual universe-repository platform;
          inherit (partitions) rootfs bootfs swapfs;
        }
      ;
      installer-module = {
        imports = [ installer-module-base ];
        config = {
          environment.systemPackages = [
            (
              log.log-debug
              { installer = "${installer-program.installer}"; }
              "nahual-installer"
              installer-program.installer
            )
          ];
        };
      };
      installers = platform.get-install-media { inherit installer-module; };
    in
      finalize-install-media-script args installers
  ;
  installers-set =
    let
      per-platform =
        nahual: nahual-context: _name: platform: create-installer { inherit nahual nahual-context platform; };
      per-nahual = nahual: nahual-context: lib.mapAttrs (per-platform nahual nahual-context) platforms;
    in
      lib.mapAttrs per-nahual nahuales
  ;
in
  {
    installers =
      if lib.isString universe-repository
      then installers-set
      else throw "To create an installer, a universe repository must be provided."
    ;
  }

