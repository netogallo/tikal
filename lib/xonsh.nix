{
  nixpkgs,
  callPackage,
  pkgs,
  lib,
  do,
  ...
}:
let
  xonsh = callPackage "${nixpkgs}/pkgs/by-name/xo/xonsh/package.nix" { extraPackages = pkgs: [ pkgs.docopt ]; }; 
  run-script = script: ''
    RAISE_SUBPROC_ERROR=True ${xonsh}/bin/xonsh "${script}" $@
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
      mk-var = name: value: ''
        with open("${save-var name value}", 'r') as jf:
          ${name} = json.load(jf)
      '';
      vars-txt = do [
        vars
        "$>" builtins.mapAttrs mk-var
        "|>" builtins.attrValues
        "|>" (vvs: [ "import json" ] ++ vvs)
        "|>" builtins.concatStringsSep "\n"
      ];
      sources-txt = do [
        sources
        "$>" map source-file
        "|>" builtins.concatStringsSep "\n"
      ];
    in
      pkgs.writeTextFile {
        inherit name;
        text = ''
        ${xonsh-init}

        ${sources-txt}

        ${vars-txt}

        ${script}
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
