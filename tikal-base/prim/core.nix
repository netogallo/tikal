{
  __description = ''
    This file contains the implementation of Tikal's module, type and value system.
    The fundamental principle behind Tikal is to introduce a new family of derivations
    called "Tikal Derivations". These derivations are meant to represent families of
    runtime values. So in essence, they can be regarded as types.

    In tikal, all values are attribute sets composed of two kinds of attributes:
    - Tikal contextual attributes
    - Exports

    The Tikal contextal attributes contain all the asociations that exist between
    Tikal derivations and runtime values. Every Tikal derivation has a unique id
    derived in a similar fashion as how nix itself derives the store path of a derivation.
    The store path itself is not used bc this introduces cyclical dependencies. This id
    is used as the attribute name for all Tikal contextual attributes. The value of said
    attribute will be the runtime value associated to a derivation for that particular
    value.

    The exports are attributes that make it easy to work with Tikal values. It would
    be cumbersome accessing the contextual values using the uids directly. Exports
    simply expose attributes from the contextual values directly in the value.

    There is a special derivation called "tikal-base" which all Tikal objects have
    as attribute. The runtime context of this derivation contains an attribute called
    "exports". This attribute is a list of all the derivation UID's and paths in the
    contextual value that will become attributes of the Tikal value. The function
    "add-exports" is used to add these attributes to a value.
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

        __functor = self: drv:
          let
            meta = builtins.fromJSON (builtins.readFile "${drv}/${tikal-meta-file}");
          in
          meta // {
            exports = [];
            tikal-base-uid = tikal-base.uid;
            __derivation = drv;
          }
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
            find "$1" -print0 -type f \
            | xargs --null -I{} hash-file {} \
          )

          echo "$hashes" | sha256sum | cut -d' ' -f1
        '';
      };

      merge-tikal-contexts = {
        __description = ''
          Merge many Tikal contexts into a single one. This will result in
          the context having the exports from all of the input contexts. The
          Tikal context of a value is a value stored under the
          "${tikal-base.uid}" attribute. This value contains:
          - The unique identifier of the current value
          - The primitive nix value used to construct the value
          - The exports of said value
          Note that this function is meant for internal use as it discards
          all the primitive values from all contexts.
        '';

        __functor = self: base: contexts:
          let
            get-exports = value:
              if builtins.hasAttr "exports" value
              then value.exports
              else []
            ;
            exports = builtins.concatMap (value: value.exports) ([base] ++ contexts);
          in
          base // { inherit exports; }
        ;
      };

      tikal-derivation = {
      
        __description = ''
        This function constructs a Tikal derivation. Tikal derivations represent
        families of values at runtime. Each derivation is meant to represent a
        different families of values.

        All tikal derivations contain a "tikal.meta.json" file as an output. This
        file contains the metadata of the derivation. The most essential metadata
        value is the "uid" or unique identifier of the derivation. This value is
        used to associate the derivation with a runtime value in a Tikal value.
        '';

        __functor =
          self:
          { 
            name,
            src,
            tikalMetaTemplate,
            nativeBuildInputs ? [],
            tikalDependencies ? [],
            dontUnpack ? true,
            dontBuild ? true,
            buildPhase ? "",
            installPhase ? "",
          }:
          let
            deps-hashes =
              builtins.concatStringsSep
                "\n"
                (
                  builtins.map
                  (x: "echo ${x.uid} >> $hashfile")
                  tikalDependencies
                )
            ;
          in
          stdenv.mkDerivation {
            inherit name src dontBuild dontUnpack;
            nativeBuildInputs = with nixpkgs; [
              envsubst
              hash-file
              hash-package
            ] ++ nativeBuildInputs;
            tikalDependencies = map (x: x.__derivation) tikalDependencies;
            buildPhase = ''
              envfile="$PWD/envfile"
              ${buildPhase}
            '';
            installPhase = ''
              mkdir -p $out
              hashfile="$out/hashfile"
              envfile="$out/envfile"
              touch $envfile
              touch $hashfile

              if [ -f $src/envfile ]; then
                cat $src/envfile >> $envfile
              fi

              if [ -f $PWD/envfile ]; then
                cat $PWD/envfile >> $envfile
              fi

              ${deps-hashes}
              ${installPhase}
              src_hash=$(hash-package $src)
              echo $src_hash >> $hashfile
              master_hash=$(hash-file $hashfile)
              echo "export uid=\"$master_hash-${name}\"" >> $envfile
              echo "export name=${name}" >> $envfile
              (source $envfile && envsubst -i ${tikalMetaTemplate} > $out/${tikal-meta-file})
            '';
          }
        ;
      };

      k-tikal-prim = "tikal-prim";

      mk-tikal-value = name:
        let
          meta-tpl = nixpkgs.writeTextFile {
            name = "${tikal-meta-file}.tpl";
            text = ''
              {
                "uid": "$uid",
                "name": "$name",
                "version": "$version"
              }
            '';
          };
          drv = tikal-derivation rec {
            inherit name;
            src = ./core/tikal-base;
            tikalMetaTemplate = meta-tpl;
          };
          meta = to-tikal-meta drv;
        in
        {
          inherit (meta) uid;
          inherit meta;
          tikal-base-uid =
            if name == k-tikal-prim
            then meta.uid
            else tikal-base.uid;
          exports = [];
        }
      ;

      tikal-base = mk-tikal-value k-tikal-prim;

      is-tikal-value = {

        __description = ''
          Check if a value is a Tikal value. A Tikal value is an attribute set
          that contains a Tikal context under the attribute "${tikal-base.uid}".
          This context contains the exports of the value.
        '';

        __functor = self: value:
          builtins.typeOf value == "set"
          && builtins.hasAttr tikal-base.uid value
        ;
      };

      is-extension = {

        __description = ''
          Check if a value is a Tikal object extension. An object extension is
          a value that allows adding new members to an existing Tikal object.
          Thikal extensions are tagged with the 'tikal-base-uid' attribute which
          contains the uid of the Tikal version of that extension.
        '';

        __functor = self: value:
          builtins.typeOf value == "set"
          && prim-lib.getAttrDeep "tikal-base-uid" value == tikal-base.uid
        ;
      };

      new-tikal-value = rec {

        __description = ''
        Adds the tikal-base context to the given attribute set and also adds
        the exports offered by tikal-base values.

        This function is meant to be used interally to manually construct Tikal
        values without relying on Tikal's type system.
        '';

        __functor = _: base-values:
          let
            base-exports = [
              { uid = tikal-base.uid; path = "members.extend"; target = "extend"; }
              { uid = tikal-base.uid; path = "members.extend-any"; target = "extend-any"; }
            ];
            base-members = value:
              let
                members =
                  prim-lib.self-overridable
                    {
                      extend = extend-member;
                      extend-any = extend-any-member;
                    }
                    value
                ;
                exports = base-exports;
              in
                { inherit exports members; }
            ;

            extend-member = self: extensions: self.extend-any { inherit extensions; };

            extend-any-member = self: { extensions }:
              let
                check-extension = ext:
                  if is-extension ext
                  then ext
                  else throw ''
                    Tikal extensions must have the 'tikal-base-uid' attribute set
                    to the uid of the Tikal base derivation used for the extension.
                  '';
                scope-extension = ext:
                  let
                    members = ext.members.__override result;
                  in
                  if builtins.hasAttr "members" ext
                  then ext // { inherit members; }
                  else ext
                ;
                cat-extensions = ext:
                  if is-extension ext
                  then [ (scope-extension ext) ]
                  else []
                ;
                existing-extensions =
                  builtins.concatMap cat-extensions (builtins.attrValues self);
                make-extension = ext: scope-extension (check-extension ext);
                all-extensions = existing-extensions ++ map make-extension extensions;
                add-extension = s: ext: s // { "${ext.uid}" = ext; };
                new-value = builtins.foldl' add-extension {} all-extensions;
                result = add-exports new-value;
              in
                result
            ;

            result =
              add-exports (
                base-values // {
                  "${tikal-base.uid}" = tikal-base // base-members result;
                }
              );
          in
          result
        ;
      };

      tikal-value = new-tikal-value {};

      add-exports = {
        __description = ''
          Given a value with a Tikal context, it constructs a new value which
          is exactly like the input but also contains additional attributes
          which are derived from the Tikal context of the value.
        '';

        __functor = self: value:
          let
            attributes = builtins.attrNames value;
            cat-extensions = attr:
              let
                ext = value."${attr}";
              in
                if is-extension ext
                then [ext]
                else []
            ;
            extensions = builtins.concatMap cat-extensions attributes;
            add-export = s: { uid, path, target ? null }:
              let
                ctx = value."${uid}";
                member = prim-lib.getAttrDeepPoly { strict = true; } path ctx;
                out-path = if target == null then path else target;
              in
                prim-lib.setAttrDeep out-path s member
              ;
            add-exports = s: ext:
              builtins.foldl' add-export s ext.exports
            ;
          in
            builtins.foldl' add-exports value extensions
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

      tikal-package = {

        __description = ''
          Creates a value that represents a Tikal package. This function takes
          as input a directory containing a "tikal.json" file which describes
          the package. The result is an attribute set which contains the metadata
          of said package as well as the derivation created to represent the package.
        '';

        __functor = self: { root, ... }:
          let
            meta = builtins.fromJSON (builtins.readFile "${root}/${tikal-package-file}");
            dependencies = builtins.map tikal-package meta.dependencies;
            tikalDependencies = builtins.map (d: d.__derivation) meta.dependencies;
            drv = tikal-derivation {
              inherit tikalDependencies;
              name = meta.name;
              src = root;
              dontBuild = null;

              tikalMetaTemplate = tikal-package-template;

              nativeBuildInputs = with nixpkgs; [
                envsubst
                tikal-modules
              ];

              buildPhase = ''
                cp -r $src/* .

                uid=$(hash-package .)
                modules=$(tikal-modules .)
                echo "export modules='[$modules]'" > $envfile
              '';

              installPhase = ''
                cp -r ./* $out
              '';
            };
          in
            to-tikal-meta drv // { inherit dependencies; }
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

      prim-ctx = {
        inherit nixpkgs prim-lib;
        value = tikal-value;
        prim-utils = {
          inherit
            hash-package
            mk-tikal-value
            tikal-meta-file
            to-tikal-meta
          ;
        };
      };

      Prim = import ../Tikal/Prim.nix prim-ctx;

      load-package-modules = {

        __description = ''
          Load a package from a derivationo which represents said package.
        '';

        __functor = self: tikal: package-meta:
          let
            package-drv = package-meta.__derivation;
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
                    (Prim.Types module-meta)
                ;
              };
            modules = map load-module package-meta.modules;
            add-module = s: m:
              prim-lib.setAttrDeep "${m.uid}.${m.name}" s m.module;
            mk-export = module:
              {
                uid = "${package-meta.uid}";
                path = "modules.${module.uid}.${module.name}";
                target = module.name;
              };
            package-extension = package-meta // {
              exports = builtins.map mk-export modules;
              modules = builtins.foldl' add-module {} modules;
            };
          in
            package-extension
        ;
      };

      tikal-base-package = tikal-package {
        root = ../.;
      };

      tikal-main-with = { tikalDependencies ? [] }:
        let
          tikal-main-tpl = nixpkgs.writeTextFile {
            name = "${tikal-meta-file}.tpl";
            text = ''
              {
                "uid": "$uid",
                "version": "$version"
              }
            '';
          };
          dependencies = [ tikal-base-package ] ++ tikalDependencies;
          drv = tikal-derivation {
            name = "tikal-main";
            tikalMetaTemplate = tikal-main-tpl;
            src = ./core/tikal-main;
            installPhase = ''
              touch $out
            '';
            tikalDependencies = dependencies;
          };
        in
        to-tikal-meta drv // { inherit dependencies; }
      ;

      tikal-main-package = tikal-main-with {};

      extend-tikal-main = {

        __description = ''
          Add additional packages to the given Nahual.
        '';

        __functor = _: self-tikal-main: { packages }:
          let
            packages = map tikal-package packages;
          in
          tikal-main-with {
            tikalDependencies = packages;
          }
        ;
      };

      load-modules = {

        __description = ''
          Load all modules from a Nahual derivation.
        '';

        __functor = self: tikal: tikal-main-package:
          let
            packages = map (load-package-modules tikal) tikal-main-package.dependencies;
          in
            tikal-value.extend packages
        ;
      };

      init-tikal-main = main-package:
        let
          tikal-main = load-modules tikal-main main-package // prim-ctx // {
            inherit nixpkgs;
            load = load-args: init-tikal-main (extend-tikal-main main-package load-args);
            load-module = nixpkgs.newScope tikal-main;
          };
        in
        tikal-main
      ;

    in
    {
      tikal = init-tikal-main tikal-main-package;
      tikal-value = import ./value.nix { inherit nixpkgs tikal-derivation; };
    }
  ;
}
