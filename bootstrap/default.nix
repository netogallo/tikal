{
  nixpkgs
}:
let
  lib = nixpkgs.lib;
  prim = import ./prim.nix { inherit nixpkgs; };
  stdenv = nixpkgs.stdenv;

  to-package-derivation = { dependencies, path, spec }:
    stdenv.mkDerivation {
      name = spec.name;
      src = path;
      dependencies = map (dep: dep.drv) dependencies;
      dontUnpack = true;
      nativeBuildInputs = with nixpkgs; [ jq ];
      buildPhase = ''
        mkdir -p build
        cp -r $src/* build/
        tikal_meta=build/tikal.json

        modules=($(find build -name "*.nix" -printf "%P\n"))

        for module in "''${modules[@]}"; do
          mv $tikal_meta tikal.tmp
          jq ".modules += [\"$module\"]" tikal.tmp > $tikal_meta
          rm tikal.tmp
        done
      '';
      installPhase = '' 
        mkdir -p $out
        cp -r build/* $out
      '';
    }
  ;

  to-package-uid = drv:
    let
      uid = prim.hash "${drv}";
    in
      "${uid}-${drv.name}"
    ;

  to-package-meta = { drv, dependencies }:
    let
      uid = to-package-uid drv;
      meta = builtins.fromJSON (builtins.readFile "${drv}/tikal.json");
    in
      meta // { inherit uid drv dependencies; }
  ;

  load-package = {

    from-path = load-package: path:
      let
        spec = builtins.fromJSON (builtins.readFile "${path}/tikal.json");
        dependencies = map load-package spec.dependencies;
        drv = to-package-derivation { inherit dependencies path spec; };
      in
        to-package-meta { inherit drv dependencies; }
    ;

    __functor = self: pkg:
      if builtins.typeOf pkg == "path"
      then self.from-path self pkg
      else throw "Cannot load a Tikal package from the provided argument."
    ;
  };

  to-module-name = path: builtins.replaceStrings [ ".nix" "/" ] [ "" "." ] path;

  to-module-meta = pkg: module:
    {
      name = to-module-name module;
      path = "${pkg.drv}/${module}";
    }
  ;

  collect-modules = pkg:
    let
      modules = map (to-module-meta pkg) pkg.modules;
    in
      modules ++ builtins.concatMap collect-modules pkg.dependencies
    ;

  base-package = load-package ../base;

  load-modules = pkg:
    let
      modules-meta = collect-modules pkg ++ collect-modules base-package;
      module-scope = nixpkgs.newScope domain;
      import-module = state: { name, path }:
        prim.setAttrDeep name state (module-scope path {});
      domain = lib.foldl import-module {} modules-meta;
    in
      domain
  ;

  tikal = {

    __description = ''
      Build an object out of a Tikal package set. The input can either be a derivation or a path.
      If a path is provided, it must be a directory containing a valid Tikal package which will
      be converted into a derivation.
    '';

    __functor = _: pkg-src:
      let
        pkg = load-package pkg-src;
      in
        load-modules pkg
    ;
  };
in
{ inherit tikal; }
