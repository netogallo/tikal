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
  inherit (tikal.prelude) list;
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
      RAISE_SUBPROC_ERROR=True XONSH_SHOW_TRACEBACK=True ${pythonpath-str} ${xonsh}/bin/xonsh "${script}" $@
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
      make-module-files = path: module':
        let
          module = { "__init__" = ""; } // module';
          mapper = name: text:
            pkgs.writeTextDir
              "lib/python3/site-packages/${path}/${name}.py"
              text
          ;
        in
          lib.mapAttrsToList mapper module
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
    
  xsh-write-script =
    {
      name
    , script
    , vars ? {}
    , sources ? []
    }:
    let
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
      save-var = name: value: pkgs.writeTextFile {
        inherit name;
        text = builtins.toJSON value;
      };
      get-path-hash = do [
        builtins.baseNameOf
        "|>" lib.splitString "-"
        "|>" builtins.head
      ];
      mk-var = name: value:
        let
          var-file = save-var name value;
          var-unique-name = "__${get-path-hash var-file}_${var-name}";
          var-name =
            lib.replaceStrings
            ["-"]
            ["_"]
            name
          ;
          var-set = ''
            from box import Box
            with open("${var-file}", "r") as jf:
              ${var-unique-name} = Box.from_json(jf.read())
          '';
          var-str = ''
            ${var-unique-name} = "${value}"
          '';
          var-decl =
            if lib.isString value
            then var-str
            else if lib.isAttrs value
            then var-set
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
      empty-vars = { bindings = {}; text = ""; };
      all-vars = do [
        vars
        "$>" builtins.mapAttrs mk-var
        "|>" builtins.attrValues
        "|>" lib.foldl combine-vars empty-vars
      ];
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
in
  {
    inherit xonsh;
    xonsh-app = {
      type = "app";
      program = "${xonsh}/bin/xonsh";
    };
    xsh = {
      inherit write-script-bin write-packages;
      write-script = xsh-write-script;
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
