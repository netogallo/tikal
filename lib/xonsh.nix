{
  nixpkgs,
  callPackage,
  pkgs,
  lib,
  pipe,
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
      vars-txt = pipe
        (builtins.concatStringsSep "\n")
        (vvs: [ "import json" ] ++ vvs)
        builtins.attrValues
        (builtins.mapAttrs mk-var)
        "<|" vars
      ;
      sources-txt = pipe
        (builtins.concatStringsSep "\n")
        (map (file: ''source "${file}"''))
        "<|" sources
      ;
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
          pipe
            run-script
            xsh-write-script
            "<|" (
              args //
              {
                inherit name script;
              }
            );
        write = args: pkgs.writeScriptBin name (script-txt args);
      in
        (write {}) //
        {
          __functor = self: vars: write vars;
        }
    ;
  }
