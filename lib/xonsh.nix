{
  nixpkgs,
  callPackage,
  pkgs,
  ...
}:
let
  xonsh = callPackage "${nixpkgs}/pkgs/by-name/xo/xonsh/package.nix" { extraPackages = pkgs: [ pkgs.docopt ]; }; 
  run-script = script: ''
    ${xonsh}/bin/xonsh ${script} $@
  '';
in
  {
    inherit xonsh;
    xonsh-app = {
      type = "app";
      program = "${xonsh}/bin/xonsh";
    };
    writeScriptBin = name: script:
      let
        script-txt = pkgs.writeTextFile {
          inherit name;
          text = script;
        };
      in
        pkgs.writeScriptBin name (run-script script-txt)
    ;
  }
