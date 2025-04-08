{
  nixpkgs,
  callPackage,
  pkgs,
  lib,
  do,
  ...
}:
let
  xonsh =
    callPackage
      "${nixpkgs}/pkgs/by-name/xo/xonsh/package.nix"
      {
        extraPackages = pkgs: with pkgs; [ colorama docopt python-box ];
      }; 
  run-script = script: ''
    #!${pkgs.bash}/bin/bash
    RAISE_SUBPROC_ERROR=True XONSH_SHOW_TRACEBACK=True ${xonsh}/bin/xonsh "${script}" $@
  '';
  xsh-write-script =
    {
      name
    , script
    , vars ? {}
    , sources ? []
    , ...
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
    
in
  {
    inherit xonsh;
    xonsh-app = {
      type = "app";
      program = "${xonsh}/bin/xonsh";
    };
    xsh = {
      write-script = xsh-write-script;
    };
    writeScriptBin = name: script:
      let
        script-txt = args:
          do [
            (args // { inherit name script; })
            "$>" xsh-write-script
            "|>" run-script
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
