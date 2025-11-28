{
  tikal-scope,
  nahual,
  universe-repository,
  system,
  rootfs,
  bootfs,
  swapfs,
  platform,
  nixpkgs,
  ...
}:
let
  inherit (tikal-scope.override { system = platform.host-platform; }) tikal pkgs;
  inherit (tikal) hardcoded;
  inherit (tikal.prelude.template) template;
  inherit (tikal.xonsh) xsh;
  flake-txt =
    ''
    {
      description = "NixOS configuration for '${nahual}' for platform '${platform.name}'.";
      inputs = {
        nixpkgs.url = "${nixpkgs.url}";
        nahual.url = "${universe-repository}";
      };
      outputs = { self, nixpkgs, nahual }: {
        nixosConfigurations.${nahual} =
          nixpkgs.lib.nixosSystem {
            system = "${platform.host-system}";
            modules = [
              {
                imports = [
                  nahual.nixosModules.${platform.host-system}.${nahual}
                ];
                config = {
                  tikal.platforms.${platform.name}.enable = true;
                  fileSystems."/" = {
                    device = "/dev/disk/by-partuuid/${rootfs.partuuid}";
                    fsType = "${rootfs.fsType}";
                  };
                  fileSystems."/boot" = {
                    device = "/dev/disk/by-partuuid/${bootfs.partuuid}";
                    fsType = "${bootfs.fsType}";
                  };
                  swapDevices =
                    [ { device = "/dev/disk/by-partuuid/${swapfs.partuuid}"; }
                    ]
                  ;
                };
              }
            ];
          }
        ;
      };
    }
    ''
  ;
  flake = pkgs.writeText "flake.nix" flake-txt;
  installer-tools = {
    sgdisk = "${pkgs.gptfdisk}/bin/sgdisk";
    curl = "${pkgs.curl}/bin/curl";
  };
  installer = xsh.write-script-bin {
    name = "tikal-install";
    vars = {
      inherit nahual flake;
      inherit (hardcoded) tikal-decrypt-keys-directory tikal-decrypt-master-key-file;
      install-device = platform.install-device;
      boot-partuuid = bootfs.partuuid;
      root-partuuid = rootfs.partuuid;
      swap-partuuid = swapfs.partuuid;
      uboot-bin-root = "${platform.uboot}";
    };
    script = { vars, ... }: template ./install.xsh (vars // installer-tools);
  };
in
  {
    inherit installer;
  }
