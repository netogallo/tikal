{
  __description = ''
  This file contains all the infrastructure to support Tikal's type and module
  system.
  '';

  __functor = self: args@{ nixpkgs, ... }:
    let
      inherit (nixpkgs) stdenv;
      prim-lib = import ./lib.nix args;

      tikal-meta-file = "tikal.meta.json";

      tikal-package-file = "tikal.json";

      to-tikal-meta = {

        __description = ''
          Given a derivation representing a Tikal entity, it will return an
          attribute set with the metadata of said entity. A derivation having
          a Tikal entity must contain a file named "${tikal-meta-file}" with at least
          a unique identifier 'uid'.
        '';

        __functor = self: drv':
          let
            drv = builtins.trace "reading: ${drv'}" drv';
            meta = builtins.fromJSON (builtins.readFile "${drv}/${tikal-meta-file}");
          in
          meta // { __derivation = drv; }
        ;
      };

      tikal-package-template = nixpkgs.writeTextFile {
        name = "${tikal-meta-file}.tpl";
        text = ''
        {
          "uid": "$uid",
          "modules": $modules
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

      merge-tikal-contexts = {
        __description = ''
          Merge many Tikal contexts into a single one. This will result in
          the context having the exports from all of the input contexts
        '';

        __functor = self: contexts:
          let
            exports = builtins.concatMap (x: x.exports) contexts;
          in
          tikal-base // { inherit exports; }
        ;
      };

      tikal-base =
        let
          meta-tpl = nixpkgs.writeTextFile {
            name = "${tikal-meta-file}.tpl";
            text = ''
              {
                "uid": "$uid",
                "name": "tikal",
                "version": "1.0.0"
              }
            '';
            destination = "/${tikal-meta-file}.tpl";
          };
          drv = stdenv.mkDerivation rec {
            name = "tikal";
            src = meta-tpl;
            nativeBuildInputs = with nixpkgs; [ envsubst hash-package ];
            dontUnpack = true;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out
              uid=$(hash-package $src)
              uid="$uid-tikal-base"
              uid=$uid envsubst -i ${src}/${tikal-meta-file}.tpl -o $out/${tikal-meta-file}
            '';
          };
          meta = to-tikal-meta drv;
        in
        {
          inherit (meta) uid;
          inherit meta;
          exports = [];
        }
      ;

      tikal-value = rec {

        __description = ''
        Constructs a Tikal value simply by inserting the most basic
        context possible. This function is not meant to be part of the
        public API. It is used internally to construct hand-rolled values.
        '';

        __functor = _: base-values:
          let
            add-members = value:
              let
                members = {
                  merge = merge-member value;
                  set-exports = set-exports-member value;
                };
              in
                value // members
            ;
                
            merge-member = self: others:
              let
                items-to-merge = [self] ++ others;
                contexts = map (x: x."${tikal-base.uid}") items-to-merge;
                context = merge-tikal-contexts contexts;
                new-value =
                  add-exports (
                    builtins.foldl'
                      (s: v: v // s)
                      { "${tikal-base.uid}" = context; }
                      items-to-merge
                  ); 
                in
                  add-members new-value;
            set-exports-member = self: exports:
              let
                new-self =
                  prim-lib.setAttrDeep
                    [ tikal-base.uid "exports" ]
                    self
                    exports
                ;
                new-value = add-exports new-self;
              in
                add-members new-value
            ;
            me = {
              "${tikal-base.uid}" = tikal-base;
            } // base-values;
          in
          add-members me
        ;
      };

      add-exports = {
        __description = ''
          Given a value with a Tikal context, it constructs a new value which
          is exactly like the input but also contains additional attributes
          which are derived from the Tikal context of the value.
        '';

        __functor = self: value:
          let
            error = ''
              Cannot add exports to a value which is not a value
              with Tiakl context.
            '';
            exports = value."${tikal-base.uid}".exports;
            extend-attributes = state: { uid, path }:
              let
                member = value."${uid}";
                item = prim-lib.getAttrDeepPoly { strict = true; } path member;
              in
              prim-lib.setAttrDeep path state item
            ;
          in
          if builtins.hasAttr tikal-base.uid value
          then builtins.foldl' extend-attributes value exports
          else throw error
        ;
      };

      tikal-file-meta-tpl = nixpkgs.writeTextFile {
        name = "tikal-file-meta.tpl";
        text = ''
          { "uid": "$uid", "path": "$path" }
        '';
      };

      to-tikal-file-meta = nixpkgs.writeShellApplication {
        name = "to-tikal-file-meta";
        runtimeInputs = [ nixpkgs.envsubst hash-file ];
        text = ''
          uid=$(hash-file "$1")
          name=$(basename "$1" | sed 's/\./-/g')
          uid="$uid-$name" path=$1 envsubst -i ${tikal-file-meta-tpl}
        '';
      };

      tikal-modules = nixpkgs.writeShellApplication {
        name = "tikal-modules";
        runtimeInputs = [ to-tikal-file-meta ];
        text = ''
          find "$1" -type f -name '*.nix' -print0 \
          | xargs --null -I{} to-tikal-file-meta {} \
          | paste -sd ','
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
            meta = builtins.fromJSON (builtins.readFile "${root}/${tikal-package-file}");
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
              modules="[$modules]"

              # todo: generate Haskell files for hoogle indexing.
              uid=$uid \
              modules=$modules \
              envsubst -i ${tikal-package-template} > ./${tikal-meta-file}
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

      type-builder = rec {

        __description = ''
          Function used to declare new types. It must be provided with a "package"
          derivation representing the package where the type will be created. This
          is usually supplied automatically when loading the module as Tiakl always
          knows to which package a module belongs to.
        '';


        type-meta-tpl = nixpkgs.writeTextFile {
          name = "${tikal-meta-file}.tpl";
          text = ''
            {
              "uid": "$uid"
            }
          '';
        };

        type-derivation = { name, module, package }:
          let
            type-src = nixpkgs.writeTextFile {
              name = "${name}.hs";
              text = ''
                module ${module}.${name} where

                package :: String
                package = "${package}"

                data ${name} = ${name}
              '';
              destination = "/${name}.hs";
            };
          in
          stdenv.mkDerivation {
            inherit name module package;
            src = nixpkgs.symlinkJoin {
              inherit name;
              paths = [ type-src ];
            };
            nativeBuildInputs = with nixpkgs; [ envsubst hash-package ];
            dontUnpack = true;
            # todo: type-check the Haskell file.
            dontBuild = true;
            installPhase = ''
              mkdir -p $out
              cp ./* $out
              uid=$(hash-package $out)
              uid=$uid envsubst -i ${type-meta-tpl} > $out/${tikal-meta-file}
            '';
          }
        ;

        __functor = self: { module, package, ...}: { name, ... }@type-decl:
          let
            drv = type-derivation {
              inherit name module package;
            };
            meta = to-tikal-meta drv;
            make-method = name: spec: self: {

              __functor = _: {};
            };
          in
          {
            "${meta.uid}" = drv; 
          }
        ;
      };

      package-from-derivation = {

        __description = ''
          Load a package from a derivationo which represents said package.
        '';

        __functor = self: tikal: package-drv:
          let
            package-meta = to-tikal-meta package-drv;
            load-module = { uid, path }:
              let
                module-name = module-name-from-path { inherit path; };
                module-meta = {
                  package = package-drv;
                  module = module-name;
                };
              in
              {
                inherit uid;
                name = module-name;
                module =
                  tikal.load-module
                    "${package-drv}/${path}"
                    { type = type-builder module-meta; }
                ;
              };
            modules = map load-module package-meta.modules;
            add-module = s: m:
              prim-lib.setAttrDeep "${m.uid}.${m.name}" s m.module;
            package-base =
              builtins.foldl'
                add-module
                { "${package-meta.uid}" = package-meta; }
                modules
            ;
            exports =
              builtins.map (x: { uid = x.uid; path = x.name; }) modules;
          in
          (tikal-value package-base).set-exports exports
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
          in
            (builtins.head packages).merge (builtins.tail packages)
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
