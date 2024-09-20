rec {
  __description = ''
  '';
  __functor = self: args@{ nixpkgs, tikal-derivation, ... }: 
  let
    tikal-derivation-meta = args:
      let
        drv = tikal-derivation args;
        meta = builtins.fromJSON (builtins.readFile "${drv}/tikal.meta.json");
      in
        meta // { derivation = drv; }
    ;

    new-value-name = "tikal-prim";
    new-value-tpl = nixpkgs.writeTextFile {
      name = "${new-value-name}.tpl";
      text = ''
        {
          "uid": "$uid",
          "name": "$name",
          "version": "$version"
        }
      '';
    };
    new-value-derivation = tikal-derivation-meta {
      name = new-value-name;
      src = ./core/tikal-base;
      tikalMetaTemplate = new-value-tpl;
    };
    extension-name = "tikal-ext";
    extension-tpl = nixpkgs.writeTextFile {
      name = "${extension-name}.tpl";
      text = ''
        {
          "uid": "$uid",
          "name": "$name",
          "version": "$version"
        }
      '';
    };
    new-extension-derivation = { name }:
      tikal-derivation-meta {
        inherit name;
        src = ./core/tikal-base;
        tikalMetaTemplate = extension-tpl;
      }
    ;
    new-extension = { name, members, ...}@spec:
      let
        drv = tikal-derivation-meta {
          name = name;
          src = ./core/tikal-base;
          tikalMetaTemplate = extension-tpl;
        };
      in
        {
          ${extension-derivation.uid} = drv;
          __functor = _: members;
        }
    ;
    extension-derivation = new-extension-derivation { name = extension-name; };
    new-value-extension = prim-value:
      {
        ${extension-derivation.uid} = extension-derivation;
        __functor = _: self: rec {
          prim = {
            __override = { member, ... }: extension:
              if Extension.eq prim-extension extension
              then prim extension
              else member extension
            ;
            __functor = _: extension:
              if Extension.eq prim-extension extension
              then prim-value
              else 
                let
                  name = extension.${extension-derivation.uid}.name;
                in
                  throw ''
                    The extension "${name}" does not override the 'prim' member.
                  ''
            ;
          };

          extends = {
            __functor = _: extension:
              let
                extension-uid = extension.${extension-derivation.uid}.uid;
              in
                if builtins.typeOf extension == "set"
                  && builtins.hasAttr extension-derivation.uid extension
                  && builtins.hasAttr new-value-derivation.uid self
                then builtins.hasAttr extension-uid self.${new-value-derivation.uid}
                else throw ''
                  This function must be called with a Tikal extension as an argument.
                ''
            ;
          };
        };
      }
    ;
    prim-extension = new-value-extension null;
    Extension = rec {
      meta = extension: extension.${extension-derivation.uid};
      name = extension: (meta extension).name;
      uid = extension: (meta extension).uid;
      eq = e1: e2: e1.${extension-derivation.uid}.uid == e2.${extension-derivation.uid}.uid;
    };
    apply-overrides = value: new-members:
      let
        override-member = current-member: new-member:
          {
            __functor = self: current-member.__override { member = new-member; };
            __override = override-args:
              current-member.__override { member = (new-member.__override override-args); }
            ;
          }
        ;
        apply-override = key: member:
          if key != extension-derivation.uid && builtins.hasAttr key value
          then override-member value.${key} member
          else member
        ;
      in
        builtins.mapAttrs apply-override new-members
    ;
    with-member-defaults = extension: members:
      let
        member-defaults = key: {
          __override = _: throw "The member '${Extension.name extension}.${key}' does not allow overriding.";
        };
        apply-default = key: member: member-defaults key // member;
      in
        builtins.mapAttrs apply-default members
    ;
    extend = extension: value:
      let
        extension-uid = Extension.uid extension;
        members = apply-overrides value (with-member-defaults extension (extension result));
        tikal-ctx = value.${new-value-derivation.uid};
        result =
          value // members // {
            ${new-value-derivation.uid} = tikal-ctx // {
              extensions = tikal-ctx.extensions ++ [ extension-uid ];
              ${extension-uid} = extension;
            };
          }
        ;
      in
        result
    ;
    new-value = {
      __functor = _: prim:
        let
          extension = new-value-extension prim;
        in
          extend extension {
            ${new-value-derivation.uid} = { extensions = []; };
          }
        ;

      __tests = {
        "It constructs a new value with the 'prim' member" =
          let
            expected = 42;
          in
            (new-value expected).prim prim-extension == expected
        ;
        "It can override the 'prim' member" =
          let
            expected-1 = "Prim is overriden";
            extension-1 = new-extension {
              name = "test-override-prim";
              members = _: {
                prim = {
                  __override = { member, ... }: extension:
                    if Extension.eq extension extension-1
                    then expected-1
                    else member extension
                  ;
                  __functor = _: _: expected-1;
                };
              };
            };
            expected-2 = 666;
            extension-2 = new-extension {
              name = "test-override-prim-2";
              members = _: {
                prim = {
                  __functor = _: _: expected-2;
                };
              };
            };
            instance = extend extension-2 (extend extension-1 (new-value 42));
          in
            instance.prim extension-1 == expected-1 && instance.prim extension-2 == expected-2
        ;
      };
    };

    to-test-results = name: results:
      let
        output =
          builtins.foldl'
            (s: { suite, test, result }: s + "\\n${suite}: ${test}: ${result}")
            ""
            results
        ;
        results-tpl = nixpkgs.writeTextFile {
          name = "${name}.tpl";
          text = ''
            {
              "uid": "$uid",
              "name": "$name",
              "version": "$version",
              "results": "${output}"
            }
          '';
        };
      in
        tikal-derivation-meta {
          name = name;
          src = ./core/tikal-base;
          tikalMetaTemplate = results-tpl;
        }
      ;

    run-tests = name: tests: value:
      let
        run-test = attr:
          if builtins.trace "Testing: ${attr}" tests.${attr}
          then { suite = name; test = attr; result = "Ok"; }
          else throw "Test failed: ${attr}"
        ;
      in map run-test (builtins.attrNames tests)
    ;

    run-test-suite = object: attr:
      let
        value = object.${attr};
        tests = value.__tests;
      in
        if builtins.hasAttr "__tests" value
        then run-tests attr tests value
        else []
    ;

    test = name: value:
      let
        results = builtins.concatMap (run-test-suite value) (builtins.attrNames value);
        results-drv = to-test-results name results;
      in
        value // { ${results-drv.uid} = results-drv; }
      ;
  in
    test "value.nix" {
      inherit new-value prim-extension;
    }
  ;
}
