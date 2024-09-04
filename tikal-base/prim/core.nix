{
  __description = ''
  This file contains all the infrastructure to support Tikal's type and module
  system.
  '';

  __functor = self: args@{ nixpkgs, ... }:
    let
      inherit (nixpkgs) stdenv;
      tikal-package-file = "tikal-package.nix";
      prim-lib = import ./lib.nix args;
      tikal-package-template = nixpkgs.writeTextFile {
        name = "${tikal-package-file}.tpl";
        text = ''
        {
          uid = "$uid";
          modules = [
        $modules
          ];
        }
        '';
      };
      hash-file = nixpkgs.writeShellApplication {
        name = "hash-file";
        text = ''
          if [ -f "$1" ]; then
            sha256sum "$1" | cut -d' ' -f1
          fi
        '';
      };

      hash-package = nixpkgs.writeShellApplication {
        name = "hash-package";
        runtimeInputs = [ hash-file ];
        text = ''
          hashes=$(\
            find "$1" -print0 -type f -name '*.nix' \
            | xargs --null -I{} hash-file {} \
          )

          echo "$hashes" | sha256sum | cut -d' ' -f1
        '';
      };

      to-tikal-file-meta = nixpkgs.writeShellApplication {
        name = "to-tikal-file-meta";
        runtimeInputs = [ hash-file ];
        text = ''
          uid=$(hash-file "$1")
          echo "    { uid = \"$uid\"; path = \"$1\"; }"
        '';
      };

      tikal-modules = nixpkgs.writeShellApplication {
        name = "tikal-modules";
        runtimeInputs = [ to-tikal-file-meta ];
        text = ''
          find "$1" -type f -name '*.nix' -print0 \
          | xargs --null -I{} to-tikal-file-meta {}
        '';
      };

      package-derivation = {

        __description = ''
          Creates a derivation for a module. The base derivation will contain
          a directory with all of the types within the module. In addition to
          all this, it will contain a few files with metadata including:
            - A file with a unique identifier for the module computed
              by hashing all of its files.
            - A file listing all types in the module.
        '';

        __functor = self: { root, ... }:
          let
            meta = builtins.fromJSON (builtins.readFile "${root}/tikal.json");
            dependencies = builtins.map package-derivation meta.dependencies;
          in
          stdenv.mkDerivation {
            inherit dependencies;
            name = meta.name;
            src = root;
            dontUnpack = true;

            nativeBuildInputs = with nixpkgs; [
              envsubst
              hash-file
              hash-package
              tikal-modules
            ];

            buildPhase = ''
              cp -r $src/* .

              uid=$(hash-package .)
              modules=$(tikal-modules .)

              # todo: generate Haskell files for hoogle indexing.
              uid=$uid \
              modules=$modules \
              envsubst -i ${tikal-package-template} > ./${tikal-package-file}
            '';

            installPhase = ''
              mkdir -p $out
              cp -r ./* $out
            '';
          }
        ;
      };

      module-name-from-path = {

        __description = ''
        Convert the path of a module to the name used within Nix to refer to
        said module. This is done by taking the relative path from the package
        and substituting all slashes with dots.
        '';

        __functor = self: { path }:
          builtins.replaceStrings ["./" "/" ".nix"] ["" "." ""] path
        ;

      };

      add-modules = {

        __description = ''
          Extend the given attribute set with all the modules provided as arguments.
          The result will contain additional attributes matching the name of the
          modules.
        '';

        __functor = self: base: modules:
          let
            add = state: module: prim-lib.setAttrDeep module.name state module.module;
          in
          builtins.foldl' add base modules
        ;
      };

      package-from-derivation = {

        __description = ''
          Load a package from a derivationo which represents said package.
        '';

        __functor = self: tikal: package-drv:
          let
            package-meta = import "${package-drv}/${tikal-package-file}";
            load-module = { uid, path }:
              {
                inherit uid;
                name = module-name-from-path { inherit path; };
                module = tikal.load-module "${package-drv}/${path}" {};
              };
            modules = map load-module package-meta.modules;
            package-base = {
              __derivation = package-drv;
              __modules = modules;
            };
          in
          add-modules package-base modules
        ;
      };

      tikal-base-package-derivation = package-derivation rec {
        root = ../.;
      };

      nahual-base-derivation = stdenv.mkDerivation {
        name = "nahual";
        src = ./.;
        dontUnpack = true;
        dontBuild = true;
        installPhase = ''
          touch $out
        '';
        dependencies = [
          tikal-base-package-derivation
        ];
      };

      extend-nahual-derivation = {

        __description = ''
          Add additional packages to the given Nahual.
        '';

        __functor = self: nahual-drv: { packages }:
          let
            packages-drv = map package-derivation packages;
          in
          nahual-drv.override {
            dependencies = nahual-drv.dependencies ++ packages-drv;
          }
        ;
      };

      load-nahual-modules = {

        __description = ''
          Load all modules from a Nahual derivation.
        '';

        __functor = self: tikal: nahual-drv:
          let
            packages = map (package-from-derivation tikal) nahual-drv.dependencies;
            modules = builtins.concatMap (x: x.__modules) packages;
          in
          add-modules { inherit modules packages; } modules
        ;
      };

      nahual = drv:
        let
          new-nahual = load-nahual-modules new-nahual drv // {
            inherit nixpkgs;
            __derivation = drv;
            load = load-args: nahual (extend-nahual-derivation drv load-args);
            load-module = nixpkgs.newScope new-nahual;
          };
        in
        new-nahual
      ;

    in
    { result = nahual nahual-base-derivation; }
  ;
}
