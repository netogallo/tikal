{ lib, pkgs, ... }:
let
  to-args-string = args:
    let
      args-def = lib.concatStringsSep "," args;
    in
      "{ ${args-def} }"
  ;
  default-get-call-context = { context, content }:
    {
      args = lib.attrNames context;
      call = file: import file;
    }
  ;
  template-overridable = { get-call-context }: path: context:
    let
      content = lib.readFile path;
      body = "''\n${content}\n''";
      call-context = get-call-context { inherit context content; };
      args = to-args-string call-context.args;
      target = pkgs.writeTextFile {
        name = "${builtins.baseNameOf path}-template.nix";
        text = ''
        ${args}:
        ${body}
        '';
      };
    in
      call-context.call "${target}" context
  ;
  template =
    lib.makeOverridable
    template-overridable
    { get-call-context = default-get-call-context; }
  ;
in
{
  inherit template;
}
