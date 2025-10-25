{
  nixpkgs,
  callPackage,
  pkgs,
  lib,
  tikal,
  ...
}:
let
  inherit (tikal.prelude) do fold-attrs-recursive;
  inherit (tikal.prelude.python) is-valid-python-identifier;
  inherit (tikal.prelude) list path;
  xonsh =
    callPackage
      "${nixpkgs}/pkgs/by-name/xo/xonsh/package.nix"
      {
        extraPackages = pkgs: with pkgs; [ colorama docopt python-box ];
      }; 
  run-script = { script, pythonpath ? [] }:
    let
      pythonpath-str =
        if lib.length pythonpath == 0
        then ""
        else ''PYTHONPATH="${lib.concatStringsSep ":" pythonpath}"''
      ;
    in
      ''
      #!${pkgs.bash}/bin/bash
      touch xonshrc
      XONSHRC="$PWD/xonshrc" HOME="$PWD" RAISE_SUBPROC_ERROR=True XONSH_SHOW_TRACEBACK=True ${pythonpath-str} ${xonsh}/bin/xonsh "${script}" $@

      exit $?
      ''
  ;
  write-packages = { name, packages }:
    let
      is-valid-python-path = path:
        let
          all-valid = lib.all is-valid-python-identifier path;
        in
          lib.length path > 1 && all-valid
      ;
      acc-files = state: path: text:
        let
          name = lib.head (list.take-end 1 path);
          path-parts = list.drop-end 1 path;
          path-str = lib.concatStringsSep "/" path-parts;
        in
          if !(is-valid-python-path path)
          then throw "The python module definition contains the invalid python path '${path-str}/${name}'"
          else [ { ${path-str} = { ${name} = text; }; } ] ++ state
      ;
      acc-modules = item: acc: acc // item;
      make-module-file-content = python-script-path: name: input:
        let
          output =
            if path.is-file-reference input
            then { text = lib.readFile input; extension = path.extension-of-checked [ "xsh" "py" ] input; }
            else { text = input; extension = "py"; }
          ;
        in
          pkgs.writeTextDir
            "lib/python3/site-packages/${python-script-path}/${name}.${output.extension}"
            output.text
      ;
      make-module-files = path: module':
        let
          module = { "__init__" = ""; } // module';
        in
          lib.mapAttrsToList (make-module-file-content path) module
      ;
      site-packages =
        do [
          packages
          "$>" fold-attrs-recursive acc-files []
          "|>" lib.foldAttrs acc-modules {}
          "|>" lib.mapAttrsToList make-module-files
          "|>" lib.concatLists
          "|>" (paths: pkgs.symlinkJoin { inherit name paths; }) 
        ]
      ;
      pythonpath = "${site-packages}/lib/python3/site-packages";
    in
      {
        inherit name site-packages pythonpath;
      }
  ;

  to-xsh-vars = vars:
    let
      mk-var = name: value:
        let
          var-file = save-var name value;
          var-unique-name = "$_${get-path-hash var-file}_${var-name}";
          var-name =
            lib.replaceStrings
            ["-"]
            ["_"]
            name
          ;
          var-object = ''
            from box import Box
            with open("${var-file}", "r") as jf:
              ${var-unique-name} = Box.from_json(jf.read())
          '';
          var-list = ''
            from box import BoxList
            with open("${var-file}", "r") as jf:
              ${var-unique-name} = BoxList.from_json(jf.read())
          '';
          var-str = ''
            ${var-unique-name} = "${value}"
          '';
          var-decl =
            if lib.isString value || lib.isDerivation value
            then var-str
            else if lib.isAttrs value
            then var-object
            else if lib.isList value
            then var-list
            else
              throw "The variable type '${lib.typeOf value}' of '${name}' is not supported by xsh."
          ;
          text = ''
            ${var-decl}
            ${var-name} = ${var-unique-name}
          '';
        in
          {
            inherit text;
            bindings = { ${name} = var-unique-name; };
          }
      ;
      combine-vars = s: var:
        {
          text = ''
            ${s.text}
            ${var.text}
          '';
          bindings = s.bindings // var.bindings;
        }
      ;
      save-var = name: value: pkgs.writeTextFile {
        inherit name;
        text = builtins.toJSON value;
      };
      get-path-hash = do [
        builtins.baseNameOf
        "|>" lib.splitString "-"
        "|>" builtins.head
      ];
      empty-vars = { bindings = {}; text = ""; };
    in
      do [
        vars
        "$>" builtins.mapAttrs mk-var
        "|>" builtins.attrValues
        "|>" lib.foldl combine-vars empty-vars
      ]
  ;
    
  xsh-write-script =
    {
      name
    , script
    , vars ? {}
    , sources ? []
    }:
    let
      all-vars = to-xsh-vars vars;
      xonsh-globals = "__XONSH_GLOBALS_8e7d3fd1_8bdf_45c4_a27b_9cf320a2e5b4";
      xonsh-init = ''
        if '${xonsh-globals}' not in globals():
          from types import SimpleNamespace
          ${xonsh-globals} = SimpleNamespace()
          ${xonsh-globals}.sources = set()
      '';
      source-file = file: ''
        if "${file}" not in ${xonsh-globals}.sources:
          source "${file}"
          ${xonsh-globals}.sources.add("${file}")
      '';

      sources-txt = do [
        sources
        "$>" map source-file
        "|>" builtins.concatStringsSep "\n"
      ];
      script-txt =
        if builtins.isFunction script
        then script { vars = all-vars.bindings; }
        else script
      ;
    in
      pkgs.writeTextFile {
        inherit name;
        text = ''
        ${xonsh-init}

        ${sources-txt}

        import json
        ${all-vars.text}

        ${script-txt}
        '';
      }
  ;
  makeXshScript = write:
    let
      script-txt =
        args@{ pythonpath ? [], ... }:
          run-script {
            inherit pythonpath;
            script = xsh-write-script (lib.attrsets.removeAttrs args [ "pythonpath" ]);
          }
      ;
    in
      write script-txt
  ;
      
  writeScript = makeXshScript (
    write: name: script:
      pkgs.writeScript name (write { inherit name script; })
  );

  write-script-bin = makeXshScript (
    write: args@{ name, ... }: pkgs.writeScriptBin name (write args)
  );
  test-xsh = { name, pythonpath ? [], script }:
    let
      script-txt =
        if lib.isFunction script
        then script {}
        else script
      ;
      test-packages = write-packages {
        name = "tests";
        packages = {
          tikal_xsh_tests = {
            tests = pkgs.writeTextFile {
              name = "tests.xsh";
              text = script-txt;
            };
          };
        };
      };
      test-support = ''
        import unittest
        import json
        import tikal_xsh_tests.tests
        import traceback
        
        class CollectingResult(unittest.TextTestResult):
        
          def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.__results = {}

          def __addResult(self, test, err = None):
            if err is None:
              success = True
              message = ""
            else:
              success = False
              (ty,val,tb) = err
              tb_str = "".join(traceback.format_tb(tb))
              message = f"{val}\n{ty}\n{tb_str}"

            key = f"{test.id()}"
            self.__results[key] = { 'success': success, 'message': message }
        
          def addSuccess(self, test):
            super().addSuccess(test)
            self.__addResult(test)
        
          def addError(self, test, err):
            super().addError(test, err)
            self.__addResult(test, err)

          def addFailure(self, test, err):
            super().addFailure(test, err)
            self.__addResult(test, err)
        
          def save_tikal(self):
            result = $TIKAL_XSH_TESTS_RESULTS
            with open(result, 'w') as fp:
              json.dump(self.__results, fp) 
        
        class CollectingRunner(unittest.TextTestRunner):
          def _makeResult(self):
            return CollectingResult(self.stream, self.descriptions, self.verbosity)

          def run(self, tests):
            result = super().run(tests)
            result.save_tikal()
            return result

        unittest.main(module='tikal_xsh_tests.tests', testRunner=CollectingRunner)
        ''
      ;
      test-script = write-script-bin {
        inherit name;
        script = lib.concatStringsSep "\n" [
          test-support
        ];
        pythonpath = [ test-packages.pythonpath ] ++ pythonpath;
      };
      test-outcome = pkgs.runCommand "${name}-outcome" {} ''
        set +e
        export TIKAL_XSH_TESTS_RESULTS=$out
        ${test-script}/bin/${name} &> output.txt
        result="$?"

        if [ ! -f "$out" ]; then
          error=$(cat output.txt)
          ${pkgs.jq}/bin/jq -n --arg message "$error" '{${name}: { success: false, message: $message }}' > $out
        fi

        if [ "$result" != 0 ]; then
          cat output.txt
        fi

        exit "$result"
      '';
      tests = do [
        test-outcome
        "$>" builtins.readFile
        "|>" builtins.unsafeDiscardStringContext
        "|>" builtins.fromJSON
      ];
      mk-test = name: { success, message }: { _assert, ... }:
        _assert.check success message
      ;
    in
      lib.mapAttrs mk-test tests
  ;
in
  {
    inherit xonsh;
    xonsh-app = {
      type = "app";
      program = "${xonsh}/bin/xonsh";
    };
    xsh = {
      inherit write-script-bin write-packages to-xsh-vars;
      write-script = xsh-write-script;
      test = test-xsh;
    };
    inherit writeScript;
    writeScriptBin = name: script:
      let
        script-txt = args:
          do [
            (args // { inherit name script; })
            "$>" xsh-write-script
            "|>" (script: run-script { inherit script; })
          ]
        ;
        write = args: pkgs.writeScriptBin name (script-txt args);
      in
        (write {}) //
        {
          __functor = self: vars: write vars;
        }
    ;
  }
