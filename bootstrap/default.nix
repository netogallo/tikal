{
  nixpkgs
}:
let
  lib = nixpkgs.lib;
  prim = import ./lib.nix { inherit nixpkgs; };
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

  load-modules = { tests-prop ? null, verbose-tests ? false }@config: pkg:
    let
      tikal-meta = {
        context-uid = pkg.uid;
        tests-uid = "${pkg.uid}-tests";
      };
      prim-context = {
        inherit nixpkgs tikal-meta prim config;
        callPackage = nixpkgs.newScope prim-context;
      };
      context-factory = import ./context.nix prim-context;
      testlib-factory = import ./test.nix prim-context; 
      type-factory = import ./type.nix prim-context; 
      modules-meta = collect-modules pkg ++ collect-modules base-package;
      module-scope = nixpkgs.newScope domain;
      import-module = { tests, state }: { name, path }@module-meta:
        let
          test = testlib-factory { inherit module-meta; };
          context = context-factory ({ inherit module-meta; } // test);
          type = type-factory ({ inherit module-meta; } // test // context);
          module-ctx = context // test // type;
          module = module-scope path module-ctx;
          module-tests =
            if builtins.hasAttr tikal-meta.tests-uid module
            then [ module.${tikal-meta.tests-uid} ]
            else []
          ;
        in
          {
            state = prim.setAttrDeep name state module;
            tests = tests ++ module-tests; 
          }
      ;
      domain = lib.foldl import-module { state = {}; tests = []; } (
        builtins.trace "modules meta: ${prim.pretty-print (map (m: m.name) modules-meta)}" modules-meta);
      tests-drv = nixpkgs.symlinkJoin {
        name = tikal-meta.tests-uid;
        paths = domain.tests;
      };
      tests-context =
        if tests-prop == null
        then {}
        else { ${tests-prop} = tests-drv; }
      ;
    in
      domain.state
      // { ${tikal-meta.tests-uid} = tests-drv; }
      // tests-context
  ;

  tikal = {

    __description = ''
      Build an object out of a Tikal package set. The input can either be a derivation or a path.
      If a path is provided, it must be a directory containing a valid Tikal package which will
      be converted into a derivation.
    '';

    __functor = _: config: pkg-src:
      let
        pkg = load-package pkg-src;
      in
        load-modules config pkg
    ;
  };
in
{ inherit tikal; }
