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

    Result =
      let
        instance-spec =
          prim-utils.mk-tikal-value "Result-instance" //
          {
            members = instance-members;
            exports = map (s: s // { uid = instance-spec.uid; }) [
              { path = "members.result"; target = "result"; }
              { path = "members.error"; target = "error"; }
              { path = "members.is-result"; target = "is-result"; }
              { path = "members.is-error"; target = "is-error"; }
              { path = "members.match"; target = "match"; }
            ];
          };
        instance-members =
          prim-lib.self-overridable
            {
              result = self: prim-lib.getAttrDeepStrict "${instance-spec.uid}.value" self;
              error = self: prim-lib.getAttrDeepStrict "${instance-spec.uid}.error" self;
              is-result = self: !self.is-error;
              is-error = self: self.error != null;
              match = self: { result, error }:
                if self.is-result
                then result self.result
                else error self.error
              ;
            }
            null
        ;
        spec =
          prim-utils.mk-tikal-value "Result" //
          {
            members = type-members;
            exports = map (s: s // {uid = spec.uid; }) [
              { path = "members.result"; target = "result"; }
              { path = "members.error"; target = "error"; }
            ];
          };
        result-type = value.extend [spec];
        type-members = prim-lib.self-overridable {
            result = self: prim-value:
              let
                new-instance = instance-spec // { value = prim-value; error = null; };
              in
                value.extend [ new-instance ]
            ;
            error = self: error:
              let
                new-instance = instance-spec // { inherit error; value = null; };
              in
                if error == null
                then throw "Cannot set a result error to null"
                else value.extend [ new-instance ]
            ;
          }
          null;
      in
        result-type
      ;
    
    type-instance-methods =
      {
        type-decl,
        instance-meta
      }: {
      new = self: _: prim-input:
        (type-decl { inherit Result; } prim-input).match {
          result = prim: instance-meta // { inherit prim; };
          error = throw;
        }
      ;

      is-instance-value = self: value:
        if prim-utils.is-tikal-value value
        then builtins.hasAttr "${instance-meta.uid}" value
        else (type-decl value).is_result
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
