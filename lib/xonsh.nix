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
        "||>" builtins.mapAttrs mk-var
        "|>" builtins.attrValues
        "|>" (vvs: [ "import json" ] ++ vvs)
        "|>" builtins.concatStringsSep "\n"
      ];
      sources-txt = do [
        sources
        "||>" map (file: ''source "${file}"'')
        "|>" builtins.concatStringsSep "\n"
      ];
    in
      pkgs.writeTextFile {
        inherit name;
        text = ''
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
            "||>" xsh-write-script
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
