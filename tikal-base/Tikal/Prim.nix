{
  __description = ''
    The "Prim" module contains several hand-rolled Tikal values that are then used
    to describe new Tikal values. Even though it looks like a regular Tikal module,
    this module can be loaded with a very limited set of functionality.

    The main export from prim is the Type value, which is then used to
    create new Types.
  '';

  __functor = self: { nixpkgs, value, prim-lib, prim-utils, ... }:
  let
    inherit (prim-utils) hash-package tikal-meta-file to-tikal-meta;
    inherit (nixpkgs) stdenv;
    type-meta-tpl = nixpkgs.writeTextFile {
      name = "${tikal-meta-file}.tpl";
      text = ''
        {
          "uid": "$uid"
        }
      '';
    };
    type-meta = prim-utils.mk-tikal-value "Type";
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
          uid="$uid-type"
          uid=$uid envsubst -i ${type-meta-tpl} > $out/${tikal-meta-file}
        '';
      }
    ;
    
    type-instance-methods =
      {
        type-decl,
        instance-meta
      }: {
      new = self: _: prim:
        let
          result = type-decl prim;
          error = prim-lib.getAttrDeep "error" prim;
          instance-ext = instance-meta // {
            prim = result;
          };
        in
          if error != null
          then throw error
          else value.extend [instance-ext]
      ;
    };
      

    new-type-member =
      self: _: { module, package, ...}: { name, ... }@type-decl:
        let
          drv = type-derivation {
            inherit name module package;
          };
          instance-meta = prim-utils.mk-tikal-value "${name}-instance";
          members = prim-lib.self-overridable (
            type-instance-methods {
              type-decl = type-decl;
              instance-meta = instance-meta;
            }
          ) null;
          meta = to-tikal-meta drv // {
            inherit instance-meta members;
            exports = [
              { uid = meta.uid; path = "members.new"; target = "__functor"; }
            ];
          };
        in
          value.extend [meta]
      ;

    type-entity = type-meta // {
      members = prim-lib.self-overridable {
        new = new-type-member;
      } null;
      exports = [
        { uid = type-meta.uid; path = "members.new"; target = "__functor"; }
      ];
    };
  in
    {
      Type = value.extend [type-entity];
    }
  ;
}
