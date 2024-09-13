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

    mk-member = {
    
      __description = ''
        Given a spec for a type member function or value, this function will
        create both a member function and the exports object to allow adding
        said member function to the type.
      '';

      __functor = self: { instance-meta, ... }: { name, spec }:
        let
          inherit (spec) type;
          member-fn-builder = { i, fn }:
            (type.get-input-arg i).match {
              result = arg: value: member-fn-builder { i = i + 1; fn = fn (arg value); };
              error = _: out-type fn;
            }
          ;
          member-fn = self: member-fn-builder { i = 0; fn = spec { inherit self; }; };
          out-type = type.out-type;
        in
          {
            members = {
              ${name} = member-fn;
            };
            exports = [
              {
                uid = instance-meta.uid;
                path = "members.${name}";
                target = "${name}";
              }
            ];
          }
      ;  
    };

    add-members = {

      __description = ''
        Given a list of member specifications, this function constructs the
        members and exports to add said members to an instance value.
      '';

      __functor = _: ctx: members:
        let
          acc = s: { members, exports }:
            {
              members = s.members // members;
              exports = s.exports ++ exports;
            }
          ;
          attr-to-member =
            name: mk-member ctx { inherit name; spec = members.${name}; };
        in
          builtins.foldl'
            acc
            { members = {}; exports = []; }
            (map attr-to-member (builtins.attrNames members))
        ;
    };
    
    type-instance-methods =
      new-type:
      {
        type-decl,
        instance-meta
      }@ctx:
      let
        defined-members = add-members ctx (type-decl.members { self-type = new-type; });
        members = prim-lib.self-overridable defined-members.members null;
        exports = defined-members.exports;
        construct-value = prim:
          let
            ctx = instance-meta // { inherit exports members prim; };
          in
            value.extend [ctx]
        ;
      in
      {
        new = self: _: prim-input:
          (type-decl { inherit Result; } prim-input).match {
            result = construct-value;
            error = throw;
          }
        ;

        is-instance-value = self: value:
          if prim-utils.is-tikal-value value
          then builtins.hasAttr "${instance-meta.uid}" value
          else (type-decl value).is_result
        ;
        
        get-input-arg = get-input-arg-member;
        out-type = out-type-member;
      }
    ;
    
    get-input-arg-member =
      self: _: Result.error "No more ags"
    ;

    out-type-member = self: self;

    new-type-member =
      self: _: { module, package, ...}: { name, ... }@type-decl:
        let
          drv = type-derivation {
            inherit name module package;
          };
          instance-meta = prim-utils.mk-tikal-value "${name}-instance";
          members =
            prim-lib.self-overridable (
              type-instance-methods new-type {
                type-decl = type-decl;
                instance-meta = instance-meta;
              }
            )
            null
          ;
          meta = to-tikal-meta drv // {
            inherit instance-meta members;
            exports = map (s: s // { uid = meta.uid; }) [
                { path = "members.new"; target = "__functor"; }
                { path = "members.get-input-arg"; target = "get-input-arg"; }
                { path = "members.out-type"; target = "out-type"; }
              ]
            ;
          };
          new-type = value.extend [meta];
        in
          new-type
      ;

    type-entity = type-meta // {
      members =
        prim-lib.self-overridable {
          new = new-type-member;
          get-input-arg = get-input-arg-member;
          out-type = out-type-member;
        }
        null;
      exports = map (s: s // { uid = type-meta.uid; }) [
        { path = "members.new"; target = "__functor"; }
      ];
    };
  in
    {
      Types = module: builtins.mapAttrs (_: spec: spec module) {
        Type = value.extend [type-entity];
        Set = _: x: x;
      };
    }
  ;
}
