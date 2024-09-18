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
    extension-derivation = tikal-derivation-meta {
      name = extension-name;
      src = ./core/tikal-base;
      tikalMetaTemplate = extension-tpl;
    };
    new-value-extension = prim: self: {
      ${extension-derivation.uid} = {
        uid = "${new-value-derivation.uid}";
      };
      prim = {
        __override = throw "override todo";
        __functor = _: _: prim;
      };
    };
    extend = extension: value:
      let
        members = extension value;
        tikal-ctx = value.${new-value-derivation.uid};
      in
        value // members // {
          ${new-value-derivation.uid} = {
            extensions = tikal-ctx.extensions ++ [ extension.${extension-derivation.uid}.uid ];
          };
        }
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
            (new-value expected).prim new-value-derivation == expected
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
      inherit new-value;
    }
  ;
}
