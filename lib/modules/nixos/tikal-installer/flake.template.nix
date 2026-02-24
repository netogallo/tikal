# This file is not final Nix code as a pre-processing stage happens
# to perform an initial variable substitution which uses ERP style
# delimiters "<% identifier %>" to avoid mixup with Nix delimiters.
# After the ERP templating stage, this file is interpreted as
# a Nix flake.
{
  description = "NixOs configuration for <% universe %> and <% nahual %>";
  inputs = {
    universe.url = "<% universe_repository %>";
    nixpkgs.follows = "universe/nixpkgs";
  };
  outputs = { self, universe, nixpkgs }:
  let
    nixosConfigurations = universe.tikal.flake-utils.each-nahual (nahual:
      nixpkgs.lib.nixosSystem {
        system = "<% platform_system %>";
        modules = [
          {
            imports = [
              universe.nixosModules.${nahual}
              <% platform_module %>
            ];
            config = {
              fileSystems."/" = {
                device = "/dev/disk/by-partuuid/<% rootfs_partuuid %>";
                fsType = "<% rootfs_fs_type %>";
              };
              fileSystems."/boot" = {
                device = "/dev/disk/by-partuuid/<% bootfs_partuuid %>";
                fsType = "<% bootfs_fs_type %>";
              };
              swapDevices = [
                { device = "/dev/disk/by-partuuid/<% swapfs_partuuid %>"; }
              ];
            };
          }
        ];
      })
    ;
  in
  {
    nixosConfigurations = nixosConfigurations // { default = nixosConfigurations.${<% nahual %>}; };
  };
}
