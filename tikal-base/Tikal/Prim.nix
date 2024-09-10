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

    new-type-member =
      self: _: { module, package, ...}: { name, ... }@type-decl:
        let
          drv = type-derivation {
            inherit name module package;
          };
          meta = to-tikal-meta drv;
          new-method = name: spec: self: {

            __functor = _: {};
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
