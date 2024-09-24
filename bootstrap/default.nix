{
  nixpkgs
}:
let
  prim = import ./prim.nix { inherit nixpkgs; };
  stdenv = nixpkgs.stdenv;

  to-package-derivation = { dependencies, path, spec }:
    stdenv.mkDerivation {
      name = spec.name;
      src = path;
      dependencies = map (dep: dep.drv) dependencies;
      dontUnpack = true;
      dontBuild = true;
      nativeBuildInputs = with nixpkgs; [ jq ];
      installPhase = ''
        mkdir -p $out
        cp -r $src/* $out

        modules=($(find $out -name "*.nix" -printf "%P\n"))
        tikal_meta=$out/tikal.json

        for module in "''${modules[@]}"; do
          jq '.modules += ["''${module}"]' $tikal_meta > $tikal_meta
        done
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

  to-module-meta = pkg: module:
    {
      
    }
  ;

  collect-modules = pkg:
    let
      modules = map (to-module-meta pkg) pkg.modules;
    in
      modules
    ;

  load-modules = pkg:
    let
      modules-meta = collect-modules pkg;
    in
    {}
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
      {}
    ;
  };
in
{}
