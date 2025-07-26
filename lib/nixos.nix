{
  pkgs,
  universe,
  lib,
  callPackage,
  tikal
}:
let
  inherit (tikal) prelude;
  flake-attrs = universe.flake;
  config = universe.config;
  tikal-user-spec = config.tikal-daemon.tikal-user-spec;
  get-public-file = { path, user ? tikal-user-spec.user, group ? tikal-user-spec.group, mode ? 640 }:
    let
      file-path-unchecked =
        if prelude.is-prefix "${flake-attrs.flake-root}" path
        then path
        else "${flake-attrs.flake-root}/${path}"
      ;
      error = "The public tikal file '${file-path-unchecked}' was not found in this flake. Did you forget to run 'sync' followed by 'git add .' before generating the nixos image?";
      file-type =
        builtins.addErrorContext error (builtins.readFileType file-path-unchecked);
      file-path =
        if file-type == "regular"
        then file-path-unchecked
        else throw "Expecting '${file-path-unchecked}' to be a file"
      ;
    in
      {
        inherit user group;
        source = file-path;
      }
  ;
  to-nixos-module = nahual: nahual-config:
    let
      core-module =
        callPackage
        ./nixos/tikal-core.nix
        {
          inherit nahual nahual-config universe get-public-file;
          nahual-modules = universe.universe-module.module.config.tikal.build.modules.${nahual};
        }
      ;
    in
      {
        imports = [ core-module.module ];
      }
  ;
in
  {
    nixos-modules = lib.mapAttrs to-nixos-module universe.flake.config.nahuales;
  }
